//
//  ManagerSocket.swift
//  Swift86
//
//  A Unix socket server that a running 86Box connects to (via the
//  86BOX_MANAGER_SOCKET environment variable) so Swift86 can control it.
//

// Foundation and Darwin only, so this file can be compiled and tested standalone
import Foundation
import Darwin

// MARK: - Manager Commands

// Commands Swift86 can send to a running 86Box
// Each protocol has its own wire form: a raw line (legacy) or a JSON message name (official)
enum ManagerCommand: String {
    case showSettings = "showsettings"
    // Toggles pause (a legacy 86Box never reports the pause state back)
    case pause
    case cad
    case reset
    case forceShutdown = "shutdownnoprompt"
    case shutdown
}

// MARK: - Manager Protocol

// Which wire protocol the 86Box on the other end speaks
enum ManagerProtocol {
    // 86Box 5.0 and later: length-prefixed JSON (QDataStream), env var VMM_86BOX_SOCKET
    case official
    // Older 86Box and forks: newline-terminated lines, env var 86BOX_MANAGER_SOCKET
    case legacy
    
    // Environment variable that hands the socket path to 86Box
    var environmentKey: String {
        switch self {
        case .official: return "VMM_86BOX_SOCKET"
        case .legacy: return "86BOX_MANAGER_SOCKET"
        }
    }
    
    // Environment for 86Box: both manager variables are stripped from the inherited one,
    // and only the chosen one is set, only when there is a socket
    static func environment(inherited: [String: String], socketPath: String?, protocol managerProtocol: ManagerProtocol) -> [String: String] {
        var environment = inherited
        environment.removeValue(forKey: ManagerProtocol.official.environmentKey)
        environment.removeValue(forKey: ManagerProtocol.legacy.environmentKey)
        if let socketPath { environment[managerProtocol.environmentKey] = socketPath }
        return environment
    }
    
    // Version string of an 86Box app, read fresh from its Info.plist (Bundle caches it)
    static func version(ofApp appURL: URL) -> String? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: plistURL),
              let info = (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
        else { return nil }
        return (info["CFBundleShortVersionString"] as? String) ?? (info["CFBundleVersion"] as? String)
    }
    
    // Choose the protocol from the emulator's version string (major 5 or later is official)
    static func forVersion(_ version: String?) -> ManagerProtocol {
        guard let version else { return .legacy }
        let digits = version.prefix(while: { $0.isASCII && $0.isNumber })
        guard let major = Int(digits), major >= 5 else { return .legacy }
        return .official
    }
}

// Running state reported by an official-protocol 86Box
enum ManagerRunningState: Int {
    case running = 0
    case paused = 1
    // Running with a modal dialog open
    case runningWaiting = 2
    // Paused with a modal dialog open
    case pausedWaiting = 3
}

extension ManagerCommand {
    // Message name in the official protocol
    fileprivate var officialName: String {
        switch self {
        case .showSettings: return "ShowSettings"
        case .pause: return "Pause"
        case .cad: return "CtrlAltDel"
        case .reset: return "ResetVM"
        case .forceShutdown: return "ForceShutdown"
        case .shutdown: return "RequestShutdown"
        }
    }
}

// MARK: - Manager Socket

// Listens for one 86Box client, sends it commands and reports what it says,
// using the legacy line protocol or the official length-prefixed JSON one
final class ManagerSocket {
    
    // MARK: - Properties
    
    // Absolute path of the socket file
    let path: String
    
    // Called on the main queue
    var onConnectionChange: ((Bool) -> Void)?
    var onModalChange: ((Bool) -> Void)?
    // Official protocol only
    var onRunningStateChange: ((ManagerRunningState) -> Void)?
    
    // Protocol spoken with 86Box, and the version string sent to it
    let managerProtocol: ManagerProtocol
    private let version: String
    
    // Everything below is only touched on the private queue
    private let queue = DispatchQueue(label: "swift86.managersocket")
    private let queueKey = DispatchSpecificKey<Bool>()
    private var listenFD: Int32 = -1
    private var clientFD: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var readSource: DispatchSourceRead?
    private var closed = false
    private var modalOpen = false
    private var receiveBuffer = [UInt8]()
    
    // MARK: - Initialization
    
    init(protocol managerProtocol: ManagerProtocol = .legacy, version: String = "Swift86") throws {
        self.managerProtocol = managerProtocol
        self.version = version
        queue.setSpecific(key: queueKey, value: true)
        
        // Short random name, the path must fit in sun_path
        let name = "s86-" + String(format: "%08x", UInt32.random(in: 0...UInt32.max)) + ".sock"
        var candidate = FileManager.default.temporaryDirectory.appendingPathComponent(name).path
        if candidate.utf8.count >= 104 { candidate = "/tmp/" + name }
        guard candidate.utf8.count < 104 else { throw POSIXError(.ENAMETOOLONG) }
        path = candidate
        
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        
        do {
            try ManagerSocket.setFlags(fd)
            
            var address = sockaddr_un()
            address.sun_family = sa_family_t(AF_UNIX)
            let capacity = MemoryLayout.size(ofValue: address.sun_path)
            precondition(path.utf8.count < capacity)
            withUnsafeMutableBytes(of: &address.sun_path) { buffer in
                for (index, byte) in path.utf8.enumerated() { buffer[index] = byte }
                buffer[path.utf8.count] = 0
            }
            
            unlink(path)
            let bound = withUnsafePointer(to: &address) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            guard bound == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            
            // Only the current user may connect
            guard chmod(path, 0o600) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
            
            guard listen(fd, 1) == 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        } catch {
            Darwin.close(fd)
            unlink(path)
            throw error
        }
        
        listenFD = fd
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.acceptClient() }
        source.setCancelHandler { Darwin.close(fd) }
        acceptSource = source
        source.resume()
    }
    
    deinit {
        close()
    }
    
    // MARK: - Helpers
    
    // Non-blocking, close-on-exec so 86Box and other children never inherit it
    private static func setFlags(_ fd: Int32) throws {
        let status = fcntl(fd, F_GETFL)
        let descriptor = fcntl(fd, F_GETFD)
        guard status >= 0, descriptor >= 0,
              fcntl(fd, F_SETFL, status | O_NONBLOCK) == 0,
              fcntl(fd, F_SETFD, descriptor | FD_CLOEXEC) == 0
        else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
    }
    
    // Run a block on the private queue, or directly when already there
    private func onQueue<T>(_ block: () -> T) -> T {
        if DispatchQueue.getSpecific(key: queueKey) == true { return block() }
        return queue.sync(execute: block)
    }
    
    // MARK: - Accepting
    
    // Accept the single 86Box client (private queue)
    private func acceptClient() {
        guard !closed, clientFD < 0 else { return }
        let fd = accept(listenFD, nil, nil)
        guard fd >= 0 else {
            // Transient errors just wait for the next event, anything else would make the source spin
            if errno != EAGAIN && errno != EINTR && errno != ECONNABORTED {
                NSLog("Swift86: manager socket accept failed (errno \(errno)), no longer listening")
                acceptSource?.cancel()
                acceptSource = nil
                listenFD = -1
            }
            return
        }
        
        // Only a process of the same user may be the client
        var uid: uid_t = 0
        var gid: gid_t = 0
        var one: Int32 = 1
        guard getpeereid(fd, &uid, &gid) == 0, uid == getuid(),
              (try? ManagerSocket.setFlags(fd)) != nil,
              setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, socklen_t(MemoryLayout<Int32>.size)) == 0
        else {
            Darwin.close(fd)
            return
        }
        
        clientFD = fd
        
        // One client only: stop listening
        acceptSource?.cancel()
        acceptSource = nil
        listenFD = -1
        
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
        source.setEventHandler { [weak self] in self?.readClient() }
        source.setCancelHandler { Darwin.close(fd) }
        readSource = source
        source.resume()
        
        notifyConnection(true)
    }
    
    // MARK: - Reading
    
    // Read what 86Box reports (private queue)
    private func readClient() {
        guard !closed, clientFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 256)
        while true {
            let count = read(clientFD, &buffer, buffer.count)
            if count > 0 {
                switch managerProtocol {
                case .legacy:
                    for byte in buffer[0..<count] {
                        // "1": a modal dialog opened in 86Box, "0": it closed
                        if byte == UInt8(ascii: "1") { setModal(true) }
                        else if byte == UInt8(ascii: "0") { setModal(false) }
                    }
                case .official:
                    receiveBuffer.append(contentsOf: buffer[0..<count])
                    if !parseFrames() {
                        // Not a sane stream, drop the client
                        disconnectClient()
                        return
                    }
                }
                if count < buffer.count { return }
            } else if count == 0 {
                disconnectClient()
                return
            } else if errno == EINTR {
                continue
            } else if errno == EAGAIN || errno == EWOULDBLOCK {
                return
            } else {
                disconnectClient()
                return
            }
        }
    }
    
    // Parse every complete QDataStream-framed JSON message in the buffer (private queue)
    // Returns false when the stream is not a valid frame sequence
    private func parseFrames() -> Bool {
        while receiveBuffer.count >= 4 {
            let length = receiveBuffer[0..<4].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
            
            // A null QByteArray
            if length == 0xFFFF_FFFF {
                receiveBuffer.removeFirst(4)
                continue
            }
            guard length <= 1 << 20 else { return false }
            guard receiveBuffer.count >= 4 + Int(length) else { break }
            
            let payload = Data(receiveBuffer[4..<(4 + Int(length))])
            receiveBuffer.removeFirst(4 + Int(length))
            handleMessage(payload)
        }
        return true
    }
    
    // Handle one client message, anything that is not a JSON object is skipped
    private func handleMessage(_ payload: Data) {
        guard let object = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any],
              let message = object["message"] as? String else { return }
        switch message {
        case "RunningStateChanged":
            let params = object["params"] as? [String: Any]
            guard let raw = (params?["status"] as? NSNumber)?.intValue,
                  let state = ManagerRunningState(rawValue: raw) else { return }
            setModal(state == .runningWaiting || state == .pausedWaiting)
            DispatchQueue.main.async { [weak self] in self?.onRunningStateChange?(state) }
        case "WindowBlocked":
            setModal(true)
        case "WindowUnblocked":
            setModal(false)
        case "ConfigurationChanged", "GlobalConfigurationChanged":
            NSLog("Swift86: 86Box reported \(message)")
        default:
            break
        }
    }
    
    private func setModal(_ value: Bool) {
        guard modalOpen != value else { return }
        modalOpen = value
        DispatchQueue.main.async { [weak self] in self?.onModalChange?(value) }
    }
    
    // The client went away (private queue)
    private func disconnectClient() {
        guard clientFD >= 0 else { return }
        readSource?.cancel()
        readSource = nil
        clientFD = -1
        setModal(false)
        notifyConnection(false)
    }
    
    private func notifyConnection(_ connected: Bool) {
        DispatchQueue.main.async { [weak self] in self?.onConnectionChange?(connected) }
    }
    
    // MARK: - Sending
    
    // Send one command, one write per line (86Box reads one line per readyRead)
    @discardableResult
    func send(_ command: ManagerCommand) -> Bool {
        onQueue {
            guard !closed, clientFD >= 0 else { return false }
            let line: [UInt8]
            switch managerProtocol {
            case .legacy:
                line = Array((command.rawValue + "\n").utf8)
            case .official:
                let message: [String: String] = ["type": "VMManager", "version": version, "message": command.officialName]
                guard let json = try? JSONSerialization.data(withJSONObject: message) else { return false }
                var length = UInt32(json.count).bigEndian
                line = withUnsafeBytes(of: &length) { Array($0) } + Array(json)
            }
            var written = -1
            repeat {
                written = write(clientFD, line, line.count)
            } while written < 0 && errno == EINTR
            guard written == line.count else {
                // A partial official frame garbles the stream, so the client is dropped
                if written > 0 && managerProtocol == .official { disconnectClient() }
                NSLog("Swift86: could not send \"\(command.rawValue)\" to 86Box (wrote \(written) of \(line.count), errno \(errno))")
                return false
            }
            return true
        }
    }
    
    // MARK: - Teardown
    
    // Idempotent: stop the sources, close the descriptors and remove the socket file
    func close() {
        onQueue {
            guard !closed else { return }
            closed = true
            acceptSource?.cancel()
            readSource?.cancel()
            acceptSource = nil
            readSource = nil
            listenFD = -1
            clientFD = -1
            unlink(path)
        }
        // Let the cancel handlers (which close the descriptors) run
        if DispatchQueue.getSpecific(key: queueKey) != true { queue.sync { } }
    }
}
