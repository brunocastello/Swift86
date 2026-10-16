//
//  MachineFiles.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation

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
