//
//  MachineFiles.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

// MARK: - Machine Name Error

// Reasons a machine name is refused
enum MachineNameError: Error, Equatable {
    case empty
    case invalidCharacters
    case leadingDot
    case tooLong
    case alreadyExists
    
    // Message shown inline in the sheet
    var message: String {
        switch self {
        case .empty: return NSLocalizedString("This machine must have a name.", comment: "")
        case .invalidCharacters: return "Names can't contain “/” or “:”."
        case .leadingDot: return "Names can't start with a period."
        case .tooLong: return "This name is too long."
        case .alreadyExists: return NSLocalizedString("A machine with this name already exists.", comment: "")
        }
    }
}

// MARK: - Machine Files

// File system helpers for machine folders (Foundation only, safe off the main thread)
enum MachineFiles {
    
    // MARK: - Name Validation
    
    // Validate a machine name, returning the trimmed name
    static func validateName(_ raw: String, in machinesURL: URL, renaming oldName: String? = nil) -> Result<String, MachineNameError> {
        // An untouched existing name is always valid, whatever created the folder
        if let oldName, raw == oldName { return .success(oldName) }
        
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if name.isEmpty { return .failure(.empty) }
        if name.contains("/") || name.contains(":") { return .failure(.invalidCharacters) }
        if name.hasPrefix(".") { return .failure(.leadingDot) }
        if name.utf8.count > 255 { return .failure(.tooLong) }
        
        // The same name is no rename
        if let oldName, name == oldName { return .success(name) }
        
        // Compare case-insensitively on any volume, hidden items included
        let fileManager = FileManager.default
        let entries = (try? fileManager.contentsOfDirectory(atPath: machinesURL.path)) ?? []
        for entry in entries where entry.compare(name, options: [.caseInsensitive]) == .orderedSame {
            // A case-only change of the machine's own folder is fine
            if let oldName, let own = identifier(machinesURL.appendingPathComponent(oldName)),
               let found = identifier(machinesURL.appendingPathComponent(entry)), own.isEqual(found) {
                continue
            }
            return .failure(.alreadyExists)
        }
        return .success(name)
    }
    
    // Identity of a file or folder on disk
    private static func identifier(_ url: URL) -> NSObjectProtocol? {
        (try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]))?.fileResourceIdentifier
    }
    
    // MARK: - Rename
    
    // Rename a machine folder by moving it, never by copying
    static func renameFolder(from old: URL, to new: URL) throws {
        let fileManager = FileManager.default
        
        if old.path.lowercased() == new.path.lowercased() && old.path != new.path {
            // Case-only rename, a single rename(2)
            var values = URLResourceValues()
            values.name = new.lastPathComponent
            var target = old
            try target.setResourceValues(values)
        } else {
            try fileManager.moveItem(at: old, to: new)
        }
    }
    
    // MARK: - Discovery
    
    // Immediate subfolders that are real directories (no hidden folders, no symlinks), nil if the folder can't be listed
    static func candidateFolders(in machinesURL: URL) -> [URL]? {
        // The folder itself may be a symlink, only the machine folders inside it must not be
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey]
        guard let items = try? FileManager.default.contentsOfDirectory(at: machinesURL.resolvingSymlinksInPath(), includingPropertiesForKeys: keys, options: [.skipsHiddenFiles]) else { return nil }
        return items.filter { url in
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { return false }
            return values.isDirectory == true && values.isSymbolicLink != true
        }
    }
    
    // Canonical path of a folder as 86Box writes it (realpath in NFC), without a trailing slash
    static func canonicalPath(_ url: URL) -> String {
        let path = VMMIni.canonicalPathString(url) ?? url.resolvingSymlinksInPath().standardizedFileURL.path.precomposedStringWithCanonicalMapping
        return RegisteredFolders.normalized(path)
    }
    
    // Folders listed in vmm.ini
    static func registeredFolders(in ini: VMMIni) -> RegisteredFolders {
        RegisteredFolders(ini: ini)
    }
    
    // A folder is a machine if it holds a regular 86box.cfg or is listed in vmm.ini
    static func isMachineFolder(_ folderURL: URL, registered: RegisteredFolders) -> Bool {
        let values = try? folderURL.appendingPathComponent("86box.cfg").resourceValues(forKeys: [.isRegularFileKey])
        return values?.isRegularFile == true || registered.contains(folderURL)
    }
    
    // MARK: - Icons
    
    // The spellings of a folder path an icon path may use: canonical and standardized
    static func folderSpellings(_ folder: URL) -> [String] {
        [canonicalPath(folder), RegisteredFolders.normalized(folder.standardizedFileURL.path)]
    }
    
    // Whether a path lies directly inside one of the folder spellings (decide this while the folder still exists)
    static func isInside(_ path: String, folderPaths: [String]) -> Bool {
        guard path.hasPrefix("/") else { return false }
        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        let spellings = [
            VMMIni.canonicalPathString(parent) ?? "",
            parent.standardizedFileURL.path
        ].map(RegisteredFolders.normalized)
        let folders = folderPaths.map(RegisteredFolders.normalized)
        return spellings.contains { folders.contains($0) }
    }
    
    // The path of a file with this icon's name inside a folder, canonical
    static func icon(_ icon: String, movedTo folder: URL) -> String {
        canonicalPath(folder) + "/" + URL(fileURLWithPath: icon).lastPathComponent
    }
    
    // The icon path after a folder was copied: the same file name in the new folder if it lay inside the old one
    static func relocatedIcon(_ icon: String, fromFolderPaths old: [String], to folder: URL) -> String {
        isInside(icon, folderPaths: old) ? Self.icon(icon, movedTo: folder) : icon
    }
    
    // Whether two paths are the same file (device and inode), or the same normalized path when they can't be read
    static func sameFile(_ a: String, _ b: String) -> Bool {
        var first = stat(), second = stat()
        if stat(a, &first) == 0 && stat(b, &second) == 0 {
            return first.st_dev == second.st_dev && first.st_ino == second.st_ino
        }
        return RegisteredFolders.normalized(a) == RegisteredFolders.normalized(b)
    }
    
    // Icon.<ext> or Icon <n>.<ext>, case-insensitive
    private static func isInstalledIconName(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasPrefix("icon") else { return false }
        let rest = lower.dropFirst(4)
        guard let dot = rest.lastIndex(of: ".") else { return false }
        let ext = rest[rest.index(after: dot)...]
        let middle = rest[..<dot]
        guard !ext.isEmpty else { return false }
        if middle.isEmpty { return true }
        guard middle.hasPrefix(" ") else { return false }
        let digits = middle.dropFirst()
        return !digits.isEmpty && digits.allSatisfy { $0 >= "0" && $0 <= "9" }
    }
    
    // Reasons an icon can't be installed
    enum IconError: LocalizedError {
        case invalidImage
        case notAFile
        
        var errorDescription: String? {
            switch self {
            case .invalidImage: return "The selected file is not a valid image."
            case .notAFile: return "“Icon.png” already exists in the machine folder and is not a file."
            }
        }
    }
    
    // The machine icon: always Icon.png inside the machine folder
    static func iconPath(in folder: URL) -> String {
        canonicalPath(folder) + "/Icon.png"
    }
    
    // PNG data of an image file: the largest representation, the longer side capped at 1024 px
    static func pngData(fromImageAt url: URL) throws -> Data {
        guard let image = NSImage(contentsOf: url) else { throw IconError.invalidImage }
        
        // Pixel size of a representation (vector ones report points)
        func pixels(_ rep: NSImageRep) -> (width: Int, height: Int) {
            rep.pixelsWide > 0 && rep.pixelsHigh > 0 ? (rep.pixelsWide, rep.pixelsHigh) : (Int(rep.size.width), Int(rep.size.height))
        }
        guard let rep = image.representations.max(by: { pixels($0).width * pixels($0).height < pixels($1).width * pixels($1).height }) else {
            throw IconError.invalidImage
        }
        let size = pixels(rep)
        guard size.width > 0, size.height > 0 else { throw IconError.invalidImage }
        
        // A bitmap that already fits is encoded as it is
        let longer = max(size.width, size.height)
        if longer <= 1024, let bitmap = rep as? NSBitmapImageRep, let png = bitmap.representation(using: .png, properties: [:]) {
            return png
        }
        
        // Otherwise draw it into a bitmap of the target size
        let scale = longer > 1024 ? 1024.0 / Double(longer) : 1.0
        let width = max(1, Int((Double(size.width) * scale).rounded()))
        let height = max(1, Int((Double(size.height) * scale).rounded()))
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
                                            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { throw IconError.invalidImage }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        rep.draw(in: NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()
        guard let png = bitmap.representation(using: .png, properties: [:]) else { throw IconError.invalidImage }
        return png
    }
    
    // Write icon data to a hidden temporary file in the machine folder
    static func stageIcon(_ data: Data, in folder: URL) throws -> URL {
        let staged = folder.appendingPathComponent(".Icon.png.\(UUID().uuidString).tmp")
        try data.write(to: staged)
        return staged
    }
    
    // Rename the staged file over the folder's Icon.png and return that file's canonical path
    static func commitIcon(staged: URL, in folder: URL) throws -> String {
        let destination = folder.appendingPathComponent("Icon.png")
        
        // Only a regular file may be replaced
        var info = stat()
        if lstat(destination.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFREG {
            try? FileManager.default.removeItem(at: staged)
            throw IconError.notAFile
        }
        guard rename(staged.path, destination.path) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: staged)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
        return VMMIni.canonicalPathString(destination) ?? iconPath(in: folder)
    }
    
    // Icon.<ext> or Icon <n>.<ext>, case-insensitive
    private static func isIconName(_ name: String) -> Bool {
        let lower = name.lowercased()
        guard lower.hasPrefix("icon") else { return false }
        let rest = lower.dropFirst(4)
        guard let dot = rest.lastIndex(of: ".") else { return false }
        let ext = rest[rest.index(after: dot)...]
        let middle = rest[..<dot]
        guard !ext.isEmpty else { return false }
        if middle.isEmpty { return true }
        guard middle.hasPrefix(" ") else { return false }
        let digits = middle.dropFirst()
        return !digits.isEmpty && digits.allSatisfy { $0 >= "0" && $0 <= "9" }
    }
    
    // Delete a regular file unless another machine's icon is that very file
    private static func removeRegularFile(_ path: String, referencedBy others: [String]) {
        if others.contains(where: { sameFile(path, $0) }) { return }
        var info = stat()
        guard lstat(path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
    
    // "Default icon": delete the folder's Icon.png unless another machine uses it
    static func removeIcon(in folder: URL, referencedBy others: [String]) {
        removeRegularFile(folder.appendingPathComponent("Icon.png").path, referencedBy: others)
    }
    
    // Delete icon copies earlier builds left in the folder: Icon <n>.<ext> and Icon.<ext> other than png
    static func removeLeftoverIcons(in folder: URL, referencedBy others: [String]) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for name in names where isIconName(name) && name.lowercased() != "icon.png" {
            removeRegularFile(folder.appendingPathComponent(name).path, referencedBy: others)
        }
    }
    
    // MARK: - Remove
    
    // Reasons a machine folder is not removed
    enum RemovalError: LocalizedError, Equatable {
        case notAFolder
        case isSymlink
        case outsideLibrary
        case isLibrary
        case notAMachine
        
        var errorDescription: String? {
            switch self {
            case .notAFolder: return "The machine folder no longer exists."
            case .isSymlink: return "The machine folder is a symbolic link, so it was left alone."
            case .outsideLibrary: return "The machine folder is not directly inside the Virtual Machines folder, so it was left alone."
            case .isLibrary: return "The machine folder is the Virtual Machines folder itself, so it was left alone."
            case .notAMachine: return "The folder is not an 86Box machine (no 86box.cfg), so it was left alone."
            }
        }
    }
    
    // Real path of a URL (all symlinks resolved), nil if it can't be resolved
    private static func realPath(_ url: URL) -> String? {
        guard let resolved = realpath(url.path, nil) else { return nil }
        defer { free(resolved) }
        return RegisteredFolders.normalized(String(cString: resolved))
    }
    
    // Whether a machine folder may be deleted: a real folder, directly inside the machines folder, that is a machine
    static func removalCheck(folder: URL, machinesURL: URL, registered: RegisteredFolders) -> Result<Void, RemovalError> {
        var info = stat()
        guard lstat(folder.path, &info) == 0 else { return .failure(.notAFolder) }
        if (info.st_mode & S_IFMT) == S_IFLNK { return .failure(.isSymlink) }
        guard (info.st_mode & S_IFMT) == S_IFDIR else { return .failure(.notAFolder) }
        
        guard let folderPath = realPath(folder), let libraryPath = realPath(machinesURL) else { return .failure(.outsideLibrary) }
        if folderPath == libraryPath { return .failure(.isLibrary) }
        let parent = RegisteredFolders.normalized((folderPath as NSString).deletingLastPathComponent)
        guard parent == libraryPath else { return .failure(.outsideLibrary) }
        
        guard isMachineFolder(folder, registered: registered) else { return .failure(.notAMachine) }
        return .success(())
    }
    
    // MARK: - Clone
    
    // Reasons a clone fails
    enum CloneError: LocalizedError {
        case destinationExists
        
        var errorDescription: String? {
            switch self {
            case .destinationExists: return NSLocalizedString("A machine with this name already exists.", comment: "")
            }
        }
    }
    
    // A name for a copy of a machine: "<name> copy", "<name> copy 2", ... not used by any folder (case-insensitive)
    // A name that already ends in " copy" or " copy <n>" is copied from its base, so "X copy" gives "X copy 2"
    static func uniqueCloneName(for name: String, in machinesURL: URL) -> String {
        var base = name
        if let range = name.range(of: " copy( [0-9]+)?$", options: .regularExpression), range.lowerBound != name.startIndex {
            base = String(name[..<range.lowerBound])
        }
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: machinesURL.path)) ?? []
        func taken(_ candidate: String) -> Bool {
            entries.contains { $0.compare(candidate, options: [.caseInsensitive]) == .orderedSame }
        }
        var candidate = "\(base) copy"
        var number = 2
        while taken(candidate) {
            candidate = "\(base) copy \(number)"
            number += 1
        }
        return candidate
    }
    
    // Name of the hidden folder a clone is copied into first, fixed length whatever the machine is called
    static let cloneTemporaryPrefix = ".swift86-cloning-"
    static func cloneTemporaryName() -> String {
        cloneTemporaryPrefix + UUID().uuidString
    }
    
    // Whether a name is exactly a clone temporary folder name
    static func isCloneTemporaryName(_ name: String) -> Bool {
        let pattern = "^\\.swift86-cloning-[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}"
        guard let range = name.range(of: pattern, options: .regularExpression) else { return false }
        return range == name.startIndex..<name.endIndex
    }
    
    // Leftovers of interrupted clones: direct, non-symlink folders with a temporary name, minus those in progress
    static func leftoverCloneFolders(in machinesURL: URL, inProgress: Set<String> = []) -> [URL] {
        let folder = machinesURL.resolvingSymlinksInPath()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return names.compactMap { name in
            guard isCloneTemporaryName(name), !inProgress.contains(name) else { return nil }
            let url = folder.appendingPathComponent(name)
            var info = stat()
            guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR else { return nil }
            return url
        }
    }
    
    // Copy a machine folder to a new one through a hidden temporary sibling, so a failed copy never shows up as a machine
    // Everything is copied, item by item at the top level. `prepare` edits the copy before it is moved into place.
    static func cloneFolder(from source: URL, to destination: URL, temporaryName: String = cloneTemporaryName(),
                            prepare: ((URL) throws -> Void)? = nil) throws {
        let fileManager = FileManager.default
        
        // Never overwrite or merge into anything (a dangling symlink counts too)
        var info = stat()
        if lstat(destination.path, &info) == 0 { throw CloneError.destinationExists }
        
        let temporary = destination.deletingLastPathComponent().appendingPathComponent(temporaryName)
        do {
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: false)
            for name in try fileManager.contentsOfDirectory(atPath: source.path) {
                try fileManager.copyItem(at: source.appendingPathComponent(name), to: temporary.appendingPathComponent(name))
            }
            try prepare?(temporary)
            try fileManager.moveItem(at: temporary, to: destination)
        } catch {
            // Only the temporary folder is ours to remove
            try? fileManager.removeItem(at: temporary)
            // A folder that appeared under the new name meanwhile
            if (error as? CocoaError)?.code == .fileWriteFileExists { throw CloneError.destinationExists }
            throw error
        }
    }
    
    // Point absolute paths into the source folder at the new folder, in the values of a 86box.cfg
    // Only a value that starts with one of the folders followed by "/" changes, everything else keeps its bytes
    static func rewriteConfigPaths(_ text: String, from folders: [String], to folder: String) -> String {
        let prefixes = folders.map { RegisteredFolders.normalized($0) + "/" }
        let target = RegisteredFolders.normalized(folder)
        
        // Split on "\n" only, a "\r" stays at the end of its line
        let lines = text.components(separatedBy: "\n")
        let rewritten = lines.map { line -> String in
            guard let equals = line.firstIndex(of: "=") else { return line }
            let afterEquals = line.index(after: equals)
            let value = line[afterEquals...].drop { $0 == " " }
            guard let prefix = prefixes.first(where: { value.hasPrefix($0) }) else { return line }
            let valueStart = value.startIndex
            return String(line[..<valueStart]) + target + "/" + String(value.dropFirst(prefix.count))
        }
        return rewritten.joined(separator: "\n")
    }
    
    // Apply the path rewrite to a folder's 86box.cfg, if it has a readable one
    static func rewriteConfig(in folder: URL, from folders: [String], to newFolder: String) throws {
        let config = folder.appendingPathComponent("86box.cfg")
        var info = stat()
        guard lstat(config.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return }
        let data = try Data(contentsOf: config)
        // A UTF-8 byte order mark is kept as it is
        let bom = Data([0xEF, 0xBB, 0xBF])
        let hasBOM = data.starts(with: bom)
        let body = hasBOM ? data.dropFirst(3) : data[...]
        // Not UTF-8: leave the file alone rather than risk changing bytes
        guard let text = String(data: Data(body), encoding: .utf8) else { return }
        let rewritten = rewriteConfigPaths(text, from: folders, to: newFolder)
        if rewritten != text { try ((hasBOM ? bom : Data()) + Data(rewritten.utf8)).write(to: config) }
    }
    
    // MARK: - NVRAM
    
    // Reasons the NVRAM can't be wiped
    enum NVRAMError: LocalizedError {
        case notAFolder
        
        var errorDescription: String? {
            switch self {
            case .notAFolder: return "The “nvr” item in the machine folder is not a regular folder, so it was left alone."
            }
        }
    }
    
    // Delete everything inside <folder>/nvr and keep the folder, symlinks are removed and never followed
    static func wipeNVRAM(in folder: URL) throws {
        let nvr = folder.appendingPathComponent("nvr")
        var info = stat()
        if lstat(nvr.path, &info) != 0 {
            if errno == ENOENT { return }
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno))
        }
        guard (info.st_mode & S_IFMT) == S_IFDIR else { throw NVRAMError.notAFolder }
        
        let fileManager = FileManager.default
        for name in try fileManager.contentsOfDirectory(atPath: nvr.path) {
            try fileManager.removeItem(at: nvr.appendingPathComponent(name))
        }
    }
    
    // MARK: - Printer Tray
    
    // Reasons the printer folder can't be used
    enum PrinterError: LocalizedError {
        case notAFolder
        
        var errorDescription: String? {
            switch self {
            case .notAFolder: return "The “printer” item in the machine folder is not a folder."
            }
        }
    }
    
    // <folder>/printer, created when missing
    static func printerFolder(in folder: URL) throws -> URL {
        let printer = folder.appendingPathComponent("printer")
        var isFolder: ObjCBool = false
        if FileManager.default.fileExists(atPath: printer.path, isDirectory: &isFolder) {
            guard isFolder.boolValue else { throw PrinterError.notAFolder }
            return printer
        }
        // A missing machine folder is an error, it is not recreated
        try FileManager.default.createDirectory(at: printer, withIntermediateDirectories: false)
        return printer
    }
    
    // MARK: - Screenshots
    
    // Image types allowed in screenshots/ (86Box itself has no extension filter)
    static let screenshotExtensions: Set<String> = ["png", "jpg", "jpeg", "bmp", "tif", "tiff", "gif"]
    
    // Regular Monitor_1* image files directly inside <folder>/screenshots, newest first
    // (content modification date, ties by name descending)
    static func screenshots(in machineFolder: URL) -> [URL] {
        let folder = machineFolder.appendingPathComponent("screenshots", isDirectory: true)
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: folder.path) else { return [] }
        
        var found = [(name: String, date: Double)]()
        for name in names where !name.hasPrefix(".") && name.lowercased().hasPrefix("monitor_1")
            && screenshotExtensions.contains((name as NSString).pathExtension.lowercased()) {
            // lstat, so symlinks and subfolders never count
            var info = stat()
            guard lstat(folder.appendingPathComponent(name).path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { continue }
            found.append((name, Double(info.st_mtimespec.tv_sec) + Double(info.st_mtimespec.tv_nsec) / 1_000_000_000))
        }
        found.sort { $0.date != $1.date ? $0.date > $1.date : $0.name > $1.name }
        return found.map { folder.appendingPathComponent($0.name) }
    }
    
    // Reasons a screenshot is not installed
    enum ScreenshotError: LocalizedError {
        case notAFile
        case notAFolder
        case invalidImage
        
        var errorDescription: String? {
            switch self {
            case .notAFile: return "The “Screenshot.png” item in the screenshots folder is not a file."
            case .notAFolder: return "The “screenshots” item in the machine folder is not a folder."
            case .invalidImage: return "The screenshot could not be read."
            }
        }
    }
    
    // <folder>/screenshots/Screenshot.png when it is a regular file
    static func customScreenshot(in folder: URL) -> URL? {
        let url = folder.appendingPathComponent("screenshots", isDirectory: true).appendingPathComponent("Screenshot.png")
        var info = stat()
        guard lstat(url.path, &info) == 0, (info.st_mode & S_IFMT) == S_IFREG else { return nil }
        return url
    }
    
    // The screenshot to show: the chosen Screenshot.png, else the most recently modified Monitor_1 one
    static func displayedScreenshot(in folder: URL) -> URL? {
        customScreenshot(in: folder) ?? screenshots(in: folder).first
    }
    
    // Copy any image into <folder>/screenshots/Screenshot.png, converted to PNG at full resolution
    static func installScreenshot(from source: URL, into folder: URL) throws {
        let directory = folder.appendingPathComponent("screenshots", isDirectory: true)
        let destination = directory.appendingPathComponent("Screenshot.png")
        
        // The folder must be a real folder, created when missing (a missing machine folder is an error)
        var info = stat()
        if lstat(directory.path, &info) == 0 {
            guard (info.st_mode & S_IFMT) == S_IFDIR else { throw ScreenshotError.notAFolder }
        }
        // Only a regular file may be replaced
        if lstat(destination.path, &info) == 0, (info.st_mode & S_IFMT) != S_IFREG { throw ScreenshotError.notAFile }
        
        guard let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { throw ScreenshotError.invalidImage }
        
        if lstat(directory.path, &info) != 0 {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        }
        
        // Hidden temporary file in the screenshots folder, then an atomic rename over the destination
        let staged = directory.appendingPathComponent(".Screenshot.png.\(UUID().uuidString).tmp")
        guard let output = CGImageDestinationCreateWithURL(staged as CFURL, UTType.png.identifier as CFString, 1, nil) else { throw ScreenshotError.invalidImage }
        CGImageDestinationAddImage(output, image, nil)
        guard CGImageDestinationFinalize(output) else {
            try? FileManager.default.removeItem(at: staged)
            throw ScreenshotError.invalidImage
        }
        guard rename(staged.path, destination.path) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: staged)
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code))
        }
    }
    
    // Delete the chosen Screenshot.png, only if it is a regular file
    static func removeChosenScreenshot(in folder: URL) throws {
        guard let url = customScreenshot(in: folder) else { return }
        try FileManager.default.removeItem(at: url)
    }
    
    // MARK: - Size
    
    // Total size of the regular files in a folder
    static func folderSize(at url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.fileSizeKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
        
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }
}
