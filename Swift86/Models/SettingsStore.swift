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

// The application configuration, kept in the app's standard user defaults
struct AppConfig: Equatable {
    
    // MARK: - Properties
    
    // Settings properties with their default values (the user defaults keys are the property names)
    var emulatorPath: String = "/Applications/86Box.app"
    var machinesPath: String = ("~/Documents" as NSString).expandingTildeInPath
    var customROMs: Bool = false
    var romsPath: String = ("~/Library/Application Support/net.86box.86Box/roms" as NSString).expandingTildeInPath
    var vmmIniPath: String = ("~/Library/Preferences/86Box/vmm.ini" as NSString).expandingTildeInPath
    var appearance: String = ""
    var showScreenshots: Bool = false
    var machineOrder: [String] = []
    var hasCompletedFirstRun: Bool = false
    
    // Default configuration, the single source of the default values
    static let defaults = AppConfig()
    
    // MARK: - Initialization
    
    init() {}
    
    // Read every key, falling back to the default when missing or wrongly typed
    init(from store: UserDefaults) {
        let d = AppConfig()
        
        // Same, for paths: blank counts as missing and a leading tilde is expanded
        func path(_ key: String, _ fallback: String) -> String {
            guard let s = store.object(forKey: key) as? String,
                  !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return fallback }
            return s.hasPrefix("~") ? (s as NSString).expandingTildeInPath : s
        }
        func bool(_ key: String, _ fallback: Bool) -> Bool {
            store.object(forKey: key) as? Bool ?? fallback
        }
        
        emulatorPath = path("emulatorPath", d.emulatorPath)
        machinesPath = path("machinesPath", d.machinesPath)
        customROMs = bool("customROMs", d.customROMs)
        romsPath = path("romsPath", d.romsPath)
        vmmIniPath = path("vmmIniPath", d.vmmIniPath)
        appearance = store.object(forKey: "appearance") as? String ?? d.appearance
        showScreenshots = bool("showScreenshots", d.showScreenshots)
        machineOrder = store.object(forKey: "machineOrder") as? [String] ?? d.machineOrder
        hasCompletedFirstRun = bool("hasCompletedFirstRun", d.hasCompletedFirstRun)
    }
    
    // MARK: - Methods
    
    // Write every key
    func write(to store: UserDefaults) {
        store.set(emulatorPath, forKey: "emulatorPath")
        store.set(machinesPath, forKey: "machinesPath")
        store.set(customROMs, forKey: "customROMs")
        store.set(romsPath, forKey: "romsPath")
        store.set(vmmIniPath, forKey: "vmmIniPath")
        store.set(appearance, forKey: "appearance")
        store.set(showScreenshots, forKey: "showScreenshots")
        store.set(machineOrder, forKey: "machineOrder")
        store.set(hasCompletedFirstRun, forKey: "hasCompletedFirstRun")
    }
}

// MARK: - Settings Store

// Owns the configuration and saves every change to the user defaults
@MainActor @Observable final class SettingsStore {
    
    // MARK: - Properties
    
    // Share it across the app
    static let shared = SettingsStore()
    
    // Current configuration, saved on every change
    var config: AppConfig {
        didSet { if config != oldValue { config.write(to: store) } }
    }
    
    // Where the settings live (the app's standard user defaults)
    @ObservationIgnored private let store: UserDefaults
    
    // MARK: - Initialization
    
    init(store: UserDefaults = .standard) {
        self.store = store
        config = AppConfig(from: store)
    }
}
