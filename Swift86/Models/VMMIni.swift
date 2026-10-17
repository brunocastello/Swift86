//
//  VMMIni.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation
import CryptoKit

// MARK: - VMM Ini Error

// Reasons the 86Box machine list can't be updated
enum VMMIniError: LocalizedError {
    case lockTimeout
    case notUTF8
    
    var errorDescription: String? {
        switch self {
        case .lockTimeout: return "The 86Box machine list is in use by another process."
        case .notUTF8: return "The 86Box machine list is not a valid UTF-8 file."
        }
    }
}

// MARK: - VMM Ini

// 86Box's vmm.ini, a QSettings INI document that keeps every untouched byte as it was read
struct VMMIni {
    
    // MARK: - Properties
    
    // Every line of the file, verbatim, without line terminators
    private var lines: [String]
    
    // Whether the last line ends with a newline
    private var endsWithNewline: Bool
    
    // Whether the file starts with a UTF-8 byte order mark (kept, never parsed)
    private var hasBOM = false
    
    // Whether the file uses CRLF line endings (the \r stays on each raw line)
    private var usesCRLF = false
    
    // Line terminator for newly inserted lines (the \n is added when joining)
    private var terminator: String { usesCRLF ? "\r" : "" }
    
    // MARK: - Initialization
    
    // An empty document
    init() {
        lines = []
        endsWithNewline = false
    }
    
    // Parse a document, a missing file gives an empty one
    init(contentsOf url: URL) throws {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            self.init()
            return
        }
        try self.init(data: data)
    }
    
    // Parse raw file contents
    init(data: Data) throws {
        self.init()
        var body = data
        if body.starts(with: [0xEF, 0xBB, 0xBF]) {
            hasBOM = true
            body = Data(body.dropFirst(3))
        }
        guard let text = String(data: body, encoding: .utf8) else { throw VMMIniError.notUTF8 }
        if text.isEmpty { return }
        var parts = text.components(separatedBy: "\n")
        let newline = parts.last == ""
        if newline { parts.removeLast() }
        lines = parts
        endsWithNewline = newline
        usesCRLF = parts.first?.hasSuffix("\r") ?? false
    }
    
    // MARK: - Serialization
    
    // The document as it would be written to disk
    func data() -> Data {
        guard !lines.isEmpty else { return hasBOM ? Data([0xEF, 0xBB, 0xBF]) : Data() }
        let text = lines.joined(separator: "\n") + (endsWithNewline ? "\n" : "")
        return (hasBOM ? Data([0xEF, 0xBB, 0xBF]) : Data()) + Data(text.utf8)
    }
    
    // MARK: - Line Helpers
    
    // A raw line without its \r
    private static func content(_ line: String) -> String {
        line.hasSuffix("\r") ? String(line.dropLast()) : line
    }
    
    // Trim only spaces and tabs, as Qt does
    private static func trim<S: StringProtocol>(_ text: S) -> String {
        var scalars = Substring(text).unicodeScalars
        while let first = scalars.first, first == " " || first == "\t" { scalars.removeFirst() }
        while let last = scalars.last, last == " " || last == "\t" { scalars.removeLast() }
        return String(scalars)
    }
    
    // Whether a raw line is empty
    private static func isBlank(_ line: String) -> Bool {
        trim(content(line)).isEmpty
    }
    
    // Name of the section a header line opens, nil for any other line
    private static func headerName(_ line: String) -> String? {
        let trimmed = trim(content(line))
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count >= 2 else { return nil }
        return String(trimmed.dropFirst().dropLast())
    }
    
    // Index of the header line and the end of the body (exclusive) of the first section with this name
    private func range(of section: String) -> (header: Int, end: Int)? {
        guard let header = lines.firstIndex(where: { Self.headerName($0) == section }) else { return nil }
        var end = header + 1
        while end < lines.count, Self.headerName(lines[end]) == nil { end += 1 }
        return (header, end)
    }
    
    // A key entry: its first line, its line count (backslash continuations included), its key and raw value
    private struct Entry {
        let index: Int
        let count: Int
        let key: String
        let raw: String
    }
    
    // Key entries of a section body
    private func entries(from start: Int, to end: Int) -> [Entry] {
        var result = [Entry]()
        var i = start
        while i < end {
            let line = Self.content(lines[i])
            let trimmed = Self.trim(line)
            guard !trimmed.isEmpty, !trimmed.hasPrefix(";"), !trimmed.hasPrefix("#"),
                  let equals = line.firstIndex(of: "=") else {
                i += 1
                continue
            }
            let key = Self.trim(line[..<equals])
            var raw = Self.trim(line[line.index(after: equals)...])
            var count = 1
            // A value ending in an odd number of backslashes continues on the next line
            while i + count < end, Self.continues(raw) {
                raw.removeLast()
                raw += Self.trim(Self.content(lines[i + count]))
                count += 1
            }
            result.append(Entry(index: i, count: count, key: key, raw: raw))
            i += count
        }
        return result
    }
    
    // Whether a raw value ends with an unescaped backslash
    private static func continues(_ raw: String) -> Bool {
        var slashes = 0
        for ch in raw.reversed() {
            if ch == "\\" { slashes += 1 } else { break }
        }
        return slashes % 2 == 1
    }
    
    // MARK: - Reading
    
    // Names of all the sections, in file order
    func sections() -> [String] {
        lines.compactMap { Self.headerName($0) }
    }
    
    // Keys of a section with their raw (still escaped) values, in file order
    func entries(in section: String) -> [(key: String, raw: String)] {
        guard let r = range(of: section) else { return [] }
        return entries(from: r.header + 1, to: r.end).map { ($0.key, $0.raw) }
    }
    
    // The unescaped value of a key, nil if absent
    func string(_ key: String, in section: String) -> String? {
        guard let r = range(of: section),
              let entry = entries(from: r.header + 1, to: r.end).last(where: { $0.key == key }) else { return nil }
        return Self.unescape(entry.raw)
    }
    
    // MARK: - Editing
    
    // Set or remove (nil) a key, escaping the value
    mutating func set(_ value: String?, for key: String, in section: String) {
        setRaw(value.map(Self.escape), for: key, in: section)
    }
    
    // Set or remove (nil) a key with an already escaped value
    mutating func setRaw(_ raw: String?, for key: String, in section: String) {
        if range(of: section) == nil {
            guard let raw else { return }
            insertSection(section, firstLine: "\(key)=\(raw)")
            return
        }
        let r = range(of: section)!
        let existing = entries(from: r.header + 1, to: r.end)
        
        if let found = existing.last(where: { $0.key == key }) {
            if let raw {
                lines.replaceSubrange(found.index..<(found.index + found.count), with: ["\(key)=\(raw)" + terminator])
            } else {
                lines.removeSubrange(found.index..<(found.index + found.count))
            }
        } else if let raw {
            // Alphabetical position among the section's keys
            let position: Int
            if let next = existing.first(where: { $0.key > key }) {
                position = next.index
            } else if let last = existing.last {
                position = last.index + last.count
            } else {
                position = r.header + 1
            }
            lines.insert("\(key)=\(raw)" + terminator, at: position)
        }
    }
    
    // Remove a section with its keys
    mutating func removeSection(_ section: String) {
        guard let r = range(of: section) else { return }
        let isLast = r.end == lines.count
        let hadSeparator = r.end > r.header + 1 && Self.isBlank(lines[r.end - 1])
        lines.removeSubrange(r.header..<r.end)
        
        // The blank line that separated the previous section from this one goes with it
        if isLast && !hadSeparator {
            while let last = lines.last, Self.isBlank(last) { lines.removeLast() }
        }
        if lines.isEmpty { endsWithNewline = false }
    }
    
    // Insert a new section after [General], in sorted position, with one blank line between sections
    private mutating func insertSection(_ section: String, firstLine: String) {
        let block = ["[\(section)]" + terminator, firstLine + terminator]
        let headers = lines.indices.compactMap { index in Self.headerName(lines[index]).map { (index, $0) } }
        
        if let next = headers.first(where: { $0.1 != "General" && $0.1 > section }) {
            lines.insert(contentsOf: block + [terminator], at: next.0)
        } else {
            if let last = lines.last, !Self.isBlank(last) { lines.append(terminator) }
            lines.append(contentsOf: block)
            endsWithNewline = true
        }
    }
    
    // MARK: - Escaping
    
    // Escape a value the way QSettingsPrivate::iniEscapedString does
    static func escape(_ value: String) -> String {
        var result = ""
        var needsQuotes = false
        var escapeNextIfHexDigit = false
        
        for scalar in value.unicodeScalars {
            let ch = scalar.value
            if ch == 0x3B || ch == 0x2C || ch == 0x3D { needsQuotes = true }
            
            // A hex digit right after a \x escape would be read as part of it
            if escapeNextIfHexDigit && Character(scalar).isHexDigit && ch < 0x80 {
                result += "\\x" + String(ch, radix: 16)
                continue
            }
            escapeNextIfHexDigit = false
            
            switch ch {
            case 0x00: result += "\\0"
            case 0x07: result += "\\a"
            case 0x08: result += "\\b"
            case 0x0C: result += "\\f"
            case 0x0A: result += "\\n"
            case 0x0D: result += "\\r"
            case 0x09: result += "\\t"
            case 0x0B: result += "\\v"
            case 0x22: result += "\\\""
            case 0x5C: result += "\\\\"
            default:
                if ch <= 0x1F {
                    result += "\\x" + String(ch, radix: 16)
                    escapeNextIfHexDigit = true
                } else {
                    result.unicodeScalars.append(scalar)
                }
            }
        }
        
        if value.hasPrefix(" ") || value.hasSuffix(" ") { needsQuotes = true }
        if needsQuotes { result = "\"" + result + "\"" }
        
        // A leading @ would read as a Qt variant type
        return value.hasPrefix("@") ? "@" + result : result
    }
    
    // Unescape a raw value the way Qt reads it (quotes removed, no list splitting)
    static func unescape(_ raw: String) -> String {
        let input = Array(raw.unicodeScalars)
        var output = String.UnicodeScalarView()
        var inQuotes = false
        var i = 0
        
        func isHex(_ s: Unicode.Scalar) -> Bool { Character(s).isHexDigit && s.value < 0x80 }
        
        while i < input.count {
            let s = input[i]
            if s == "\"" {
                inQuotes.toggle()
                i += 1
            } else if s == "\\" && i + 1 < input.count {
                let next = input[i + 1]
                i += 2
                switch next {
                case "a": output.append(Unicode.Scalar(7))
                case "b": output.append(Unicode.Scalar(8))
                case "f": output.append(Unicode.Scalar(12))
                case "n": output.append("\n")
                case "r": output.append("\r")
                case "t": output.append("\t")
                case "v": output.append(Unicode.Scalar(11))
                case "x":
                    var value: UInt32 = 0
                    var digits = 0
                    while i < input.count, digits < 4, isHex(input[i]) {
                        value = value * 16 + UInt32(String(input[i]), radix: 16)!
                        i += 1
                        digits += 1
                    }
                    output.append(Unicode.Scalar(value) ?? "\u{FFFD}")
                case "0"..."7":
                    // Up to three octal digits, \0 being the NUL escape
                    var value = next.value - 0x30
                    var digits = 1
                    while i < input.count, digits < 3, ("0"..."7").contains(input[i]) {
                        value = value * 8 + (input[i].value - 0x30)
                        i += 1
                        digits += 1
                    }
                    output.append(Unicode.Scalar(value) ?? "\u{FFFD}")
                default:
                    // \" \\ \; \, \= and anything else stand for themselves
                    output.append(next)
                }
            } else {
                output.append(s)
                i += 1
            }
        }
        
        let result = String(output)
        // A leading @@ is a literal @
        return result.hasPrefix("@@") ? String(result.dropFirst()) : result
    }
    
    // MARK: - Machine Identity
    
    // The folder's realpath(3) bytes exactly as the file system returns them, nil if it can't be resolved
    static func canonicalPathBytes(_ url: URL) -> [UInt8]? {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        return Array(UnsafeBufferPointer(start: UnsafeRawPointer(resolved).assumingMemoryBound(to: UInt8.self), count: strlen(resolved)))
    }
    
    // The folder's canonical path as Qt's canonicalPath() gives it on macOS: realpath decoded as UTF-8, then NFC
    static func canonicalPathString(_ url: URL) -> String? {
        canonicalPathBytes(url).map { String(decoding: $0, as: UTF8.self).precomposedStringWithCanonicalMapping }
    }
    
    // Section name of a machine folder: the UUIDv5 86Box derives from the folder's canonical path
    static func uuid(forMachineFolder url: URL) -> String {
        let path = canonicalPathString(url) ?? url.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        return uuid(forCanonicalPath: path + "/")
    }
    
    // UUIDv5 with the nil namespace of an already canonical path (trailing slash included)
    static func uuid(forCanonicalPath path: String) -> String {
        uuid(forCanonicalBytes: Array(path.utf8))
    }
    
    // UUIDv5 with the nil namespace of the given bytes
    static func uuid(forCanonicalBytes name: [UInt8]) -> String {
        var input = Data(count: 16)
        input.append(contentsOf: name)
        var bytes = Array(Insecure.SHA1.hash(data: input).prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        let hex = bytes.map { String(format: "%02x", $0) }
        return [hex[0...3], hex[4...5], hex[6...7], hex[8...9], hex[10...15]].map { $0.joined() }.joined(separator: "-")
    }
    
    // MARK: - Writing
    
    #if DEBUG
    // Replace the file atomically under the Qt lock protocol (tests only, the app writes through update)
    static func write(_ doc: VMMIni, to url: URL) throws {
        try withLock(for: url) { try atomicWrite(doc.data(), to: url) }
    }
    #endif
    
    // Lock, read the file fresh, change it, write it, unlock
    static func update(at url: URL, _ body: (inout VMMIni) throws -> Void) throws {
        try withLock(for: url) {
            var doc = try VMMIni(contentsOf: url.resolvingSymlinksInPath())
            let before = doc.data()
            try body(&doc)
            // Leave the file alone when nothing changed
            if doc.data() != before { try atomicWrite(doc.data(), to: url) }
        }
    }
    
    // Write to a temporary file next to the target, then rename it over the target
    private static func atomicWrite(_ data: Data, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        if FileManager.default.fileExists(atPath: target.path), access(target.path, W_OK) != 0 {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        }
        let temp = target.deletingLastPathComponent().appendingPathComponent(".\(target.lastPathComponent).\(UUID().uuidString).tmp")
        do {
            try data.write(to: temp)
            
            // Get the bytes to disk before the rename makes them the real file
            let fd = open(temp.path, O_WRONLY)
            if fd >= 0 {
                if fcntl(fd, F_FULLFSYNC) == -1 { fsync(fd) }
                close(fd)
            }
            if let permissions = (try? FileManager.default.attributesOfItem(atPath: target.path))?[.posixPermissions] {
                try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: temp.path)
            }
            guard rename(temp.path, target.path) == 0 else {
                throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
            }
        } catch {
            try? FileManager.default.removeItem(at: temp)
            throw error
        }
    }
    
    // Run a body holding <file>.lock, which is how Qt keeps QSettings writers apart
    private static func withLock<T>(for url: URL, _ body: () throws -> T) throws -> T {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        // Qt names the lock after the path it was given, symlinks unresolved
        let lockPath = url.path + ".lock"
        
        var host = [CChar](repeating: 0, count: 256)
        gethostname(&host, host.count - 1)
        let contents = "\(getpid())\n\(ProcessInfo.processInfo.processName)\n\(String(cString: host))\n"
        
        let deadline = Date().addingTimeInterval(2)
        while true {
            let fd = open(lockPath, O_CREAT | O_EXCL | O_WRONLY, 0o644)
            if fd >= 0 {
                _ = contents.withCString { Darwin.write(fd, $0, strlen($0)) }
                close(fd)
                break
            }
            guard errno == EEXIST else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            
            // Take over a lock whose owner is gone or that has been there too long
            switch lockState(lockPath) {
            case .gone:
                continue
            case .stale:
                // If it can't be removed, wait like for a live lock instead of spinning
                if unlink(lockPath) == 0 || errno == ENOENT { continue }
            case .held:
                break
            }
            if Date() >= deadline { throw VMMIniError.lockTimeout }
            usleep(50_000)
        }
        defer { unlink(lockPath) }
        return try body()
    }
    
    private enum LockState {
        case gone
        case stale
        case held
    }
    
    // A lock is stale if its process is dead or it is older than 30 seconds
    private static func lockState(_ lockPath: String) -> LockState {
        var info = stat()
        guard stat(lockPath, &info) == 0 else { return errno == ENOENT ? .gone : .held }
        if Date().timeIntervalSince1970 - Double(info.st_mtimespec.tv_sec) > 30 { return .stale }
        
        guard let text = try? String(contentsOfFile: lockPath, encoding: .utf8),
              let pid = Int32(text.components(separatedBy: "\n").first ?? "") else { return .held }
        return kill(pid, 0) == -1 && errno == ESRCH ? .stale : .held
    }
}

// MARK: - Registered Folders

// The config_dir values of a vmm.ini, to tell whether a folder is listed
struct RegisteredFolders {
    
    // NFC form of each config_dir, without a trailing slash
    private var paths = Set<String>()
    
    init(ini: VMMIni) {
        for section in ini.sections() {
            if let dir = ini.string("config_dir", in: section), !dir.isEmpty {
                paths.insert(Self.normalized(dir))
            }
        }
    }
    
    // A path without one trailing slash, in NFC
    static func normalized(_ path: String) -> String {
        let composed = path.precomposedStringWithCanonicalMapping
        return composed.count > 1 && composed.hasSuffix("/") ? String(composed.dropLast()) : composed
    }
    
    // Whether a folder is listed, comparing its canonical path with the config_dir values
    func contains(_ folder: URL) -> Bool {
        let path = VMMIni.canonicalPathString(folder) ?? folder.standardizedFileURL.path
        return paths.contains(Self.normalized(path))
    }
}
