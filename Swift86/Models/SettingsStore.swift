//
//  SettingsStore.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import Foundation
import Observation

// MARK: - Configuration Model

// The persisted application configuration (Settings.json)
struct AppConfig: Codable, Equatable {
    
    // MARK: - Properties
    
    // Settings properties with their default values
    var schemaVersion: Int = 1
    var emulatorPath: String = "/Applications/86Box.app"
    var machinesPath: String = ("~/Documents" as NSString).expandingTildeInPath
    var customROMs: Bool = false
    var romsPath: String = ("~/Library/Application Support/net.86box.86Box/roms" as NSString).expandingTildeInPath
    var vmmIniPath: String = ("~/Library/Preferences/86Box/vmm.ini" as NSString).expandingTildeInPath
    var appearance: String = ""
    var showScreenshots: Bool = false
    var useClassicStyling: Bool = false
    var machineOrder: [String] = []
    var hasCompletedFirstRun: Bool = false
    
    // Default configuration, the single source of the default values
    static let defaults = AppConfig()
    
    // MARK: - Initialization
    
    init() {}
    
    // Decode every key leniently, falling back to the default when missing
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppConfig()
        
        // Decode one key, falling back to the default if missing or wrongly typed
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            ((try? container.decodeIfPresent(T.self, forKey: key)) ?? nil) ?? fallback
        }
        
        // Same, for paths: blank counts as missing and a leading tilde is expanded
        func path(_ key: CodingKeys, _ fallback: String) -> String {
            let s: String = value(key, fallback)
            return s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : Self.expand(s)
        }
        
        schemaVersion = value(.schemaVersion, d.schemaVersion)
        emulatorPath = path(.emulatorPath, d.emulatorPath)
        machinesPath = path(.machinesPath, d.machinesPath)
        customROMs = value(.customROMs, d.customROMs)
        romsPath = path(.romsPath, d.romsPath)
        vmmIniPath = path(.vmmIniPath, d.vmmIniPath)
        appearance = value(.appearance, d.appearance)
        showScreenshots = value(.showScreenshots, d.showScreenshots)
        useClassicStyling = value(.useClassicStyling, d.useClassicStyling)
        machineOrder = value(.machineOrder, d.machineOrder)
        hasCompletedFirstRun = value(.hasCompletedFirstRun, d.hasCompletedFirstRun)
    }
    
    // MARK: - Methods
    
    // Expand a leading tilde in a path
    private static func expand(_ path: String) -> String {
        path.hasPrefix("~") ? (path as NSString).expandingTildeInPath : path
    }
}

// MARK: - Settings Store

// Owns the configuration and persists every change to disk
@MainActor @Observable final class SettingsStore {
    
    // MARK: - Properties
    
    // Share it across the app
    static let shared = SettingsStore()
    
    // Current configuration, saved on every change
    var config: AppConfig {
        didSet { if config != oldValue { save() } }
    }
    
    // True only in the launch where the legacy UserDefaults import ran
    @ObservationIgnored private(set) var didImportLegacySettings = false
    
    // Error found while decoding an existing file, if any
    @ObservationIgnored private(set) var loadError: Error?
    
    // Error from the last failed save, if any
    @ObservationIgnored private(set) var lastSaveError: Error?
    
    // Whether the unreadable file has already been backed up
    @ObservationIgnored private var didBackUpCorruptFile = false
    
    // Location of the settings file
    @ObservationIgnored private let fileURL: URL
    
    // Default location: ~/Library/Application Support/Swift86/Settings.json
    nonisolated static var defaultFileURL: URL {
        (FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support"))
            .appendingPathComponent("Swift86", isDirectory: true)
            .appendingPathComponent("Settings.json")
    }
    
    // MARK: - Initialization
    
    init(fileURL: URL = SettingsStore.defaultFileURL, legacyDefaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        
        // Make sure the containing folder exists
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        
        if FileManager.default.fileExists(atPath: fileURL.path) {
            // Load the existing file, keeping it untouched if it cannot be decoded
            do {
                let data = try Data(contentsOf: fileURL)
                config = try JSONDecoder().decode(AppConfig.self, from: data)
            } catch {
                config = .defaults
                loadError = error
                NSLog("Swift86: could not read settings: \(error)")
            }
        } else {
            // First launch of the new format: import the legacy UserDefaults values
            config = Self.importLegacy(from: legacyDefaults)
            didImportLegacySettings = true
            save()
        }
    }
    
    // MARK: - Methods
    
    // Build a configuration from the legacy UserDefaults keys
    private static func importLegacy(from defaults: UserDefaults) -> AppConfig {
        var c = AppConfig()
        
        // A missing or empty string path keeps the default
        func path(_ key: String) -> String? {
            guard let s = defaults.object(forKey: key) as? String, !s.isEmpty else { return nil }
            return (s as NSString).expandingTildeInPath
        }
        
        if let p = path("EmulatorPath") { c.emulatorPath = p }
        if let p = path("MachinesPath") { c.machinesPath = p }
        if let p = path("RomsPath") { c.romsPath = p }
        if let b = defaults.object(forKey: "CustomROMs") as? Bool { c.customROMs = b }
        if let s = defaults.object(forKey: "Appearance") as? String { c.appearance = s }
        if let b = defaults.object(forKey: "First Run") as? Bool { c.hasCompletedFirstRun = b }
        return c
    }
    
    // Write the configuration atomically as pretty-printed JSON
    func save() {
        // Keep a copy of an unreadable file before the first overwrite
        if loadError != nil, !didBackUpCorruptFile {
            didBackUpCorruptFile = true
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let backup = fileURL.deletingLastPathComponent()
                .appendingPathComponent("Settings.corrupt-\(formatter.string(from: Date())).json")
            do {
                try FileManager.default.copyItem(at: fileURL, to: backup)
            } catch {
                NSLog("Swift86: could not back up unreadable settings: \(error)")
            }
        }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(config).write(to: fileURL, options: .atomic)
            lastSaveError = nil
        } catch {
            lastSaveError = error
            NSLog("Swift86: could not save settings: \(error)")
        }
    }
}
