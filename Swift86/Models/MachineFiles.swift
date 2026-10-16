//
//  MachineFiles.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation
import AppKit

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
