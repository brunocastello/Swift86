//
//  LegacyImport.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation

// MARK: - Legacy Import

// The only code that reads the old per-machine 86box.plist and the MachinesList UserDefaults key (read-only)
enum LegacyImport {
    
    // MARK: - Helpers
    
    // Read the "Information" dictionary of a machine's legacy plist
    private static func information(at machineURL: URL) -> [String: Any]? {
        let plistURL = machineURL.appendingPathComponent("86box.plist")
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return nil }
        guard let properties = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let info = properties["Information"] as? [String: Any] else {
            NSLog("Swift86: could not read \(plistURL.path)")
            return nil
        }
        return info
    }
    
    // MARK: - Machine Notes
    
    // Create the sidecar from the legacy plist notes, never touching the plist
    static func importMachineIfNeeded(at machineURL: URL) {
        let sidecar = machineURL.appendingPathComponent(MachineMetadata.fileName)
        guard !FileManager.default.fileExists(atPath: sidecar.path),
              let info = information(at: machineURL) else { return }
        
        do {
            try MachineMetadata(notes: info["Notes"] as? String ?? "").save(to: machineURL)
        } catch {
            NSLog("Swift86: could not import legacy machine \(machineURL.lastPathComponent): \(error)")
        }
    }
    
    // MARK: - Machine Order
    
    // Legacy sidebar order as folder names, mapped from the stored machine UUIDs
    static func legacyMachineOrder(machinesURL: URL, defaults: UserDefaults = .standard) -> [String] {
        guard let ids = defaults.stringArray(forKey: "MachinesList"), !ids.isEmpty,
              let folders = MachineMetadata.candidateFolders(in: machinesURL) else { return [] }
        
        // Map machine UUIDs to folder names
        var namesByID = [String: String]()
        for folder in folders {
            if let id = information(at: folder)?["Id"] as? String, namesByID[id] == nil {
                namesByID[id] = folder.lastPathComponent
            }
        }
        
        // Keep the stored order, dropping stale UUIDs
        return ids.compactMap { namesByID[$0] }
    }
}
