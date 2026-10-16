//
//  LegacyImport.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation

// MARK: - Legacy Import

// The only code that reads the old per-machine 86box.plist, the MachinesList UserDefaults key and the old .swift86.json sidecar
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
    
    // Notes of the legacy plist, nil if absent
    static func plistNotes(at machineURL: URL) -> String? {
        information(at: machineURL)?["Notes"] as? String
    }
    
    // Notes of Swift86's old .swift86.json sidecar (migration only), nil if absent or unreadable
    static func sidecarNotes(at machineURL: URL) -> String? {
        guard let data = try? Data(contentsOf: sidecarURL(at: machineURL)),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return object["notes"] as? String ?? ""
    }
    
    // Delete the old sidecar, if it is a regular file
    static func removeSidecar(at machineURL: URL) {
        let url = sidecarURL(at: machineURL)
        let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values?.isRegularFile == true, values?.isSymbolicLink != true else { return }
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            NSLog("Swift86: could not remove \(url.path): \(error)")
        }
    }
    
    private static func sidecarURL(at machineURL: URL) -> URL {
        machineURL.appendingPathComponent(".swift86.json")
    }
    
    // MARK: - Machine Order
    
    // Legacy sidebar order as folder names, mapped from the stored machine UUIDs
    static func legacyMachineOrder(machinesURL: URL, defaults: UserDefaults = .standard) -> [String] {
        guard let ids = defaults.stringArray(forKey: "MachinesList"), !ids.isEmpty,
              let folders = MachineFiles.candidateFolders(in: machinesURL) else { return [] }
        
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
