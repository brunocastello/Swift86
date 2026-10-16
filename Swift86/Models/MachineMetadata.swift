//
//  MachineMetadata.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation

// MARK: - Machine Metadata

// Swift86's own per-machine data, stored in a hidden sidecar inside the machine folder
struct MachineMetadata: Codable, Equatable {
    
    // MARK: - Properties
    
    var schemaVersion = 1
    var notes = ""
    
    // Sidecar file name
    static let fileName = ".swift86.json"
    
    // MARK: - Initialization
    
    init(notes: String = "") {
        self.notes = notes
    }
    
    // Decode every key leniently, falling back to the default when missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = MachineMetadata()
        schemaVersion = ((try? container.decodeIfPresent(Int.self, forKey: .schemaVersion)) ?? nil) ?? d.schemaVersion
        notes = ((try? container.decodeIfPresent(String.self, forKey: .notes)) ?? nil) ?? d.notes
    }
    
    // MARK: - Load and Save
    
    // Load the sidecar, nil if absent and defaults if unreadable
    static func load(from machineURL: URL) -> MachineMetadata? {
        let fileURL = machineURL.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            return try JSONDecoder().decode(MachineMetadata.self, from: Data(contentsOf: fileURL))
        } catch {
            NSLog("Swift86: could not read \(fileURL.path): \(error)")
            return MachineMetadata()
        }
    }
    
    // Save the sidecar atomically
    func save(to machineURL: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: machineURL.appendingPathComponent(Self.fileName), options: .atomic)
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
    
    // A folder is a machine if it holds a regular 86box.cfg or a Swift86 sidecar
    static func isMachineFolder(_ folderURL: URL) -> Bool {
        ["86box.cfg", fileName].contains { name in
            let values = try? folderURL.appendingPathComponent(name).resourceValues(forKeys: [.isRegularFileKey])
            return values?.isRegularFile == true
        }
    }
}
