//
//  SettingsViewModel.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings Data

// Handles user settings data and interactions
class SettingsViewModel: ObservableObject {
    
    // MARK: - Properties
    
    // The default app settings
    let defaults: [String : Any] = DefaultSettings.shared.defaults
    
    // Published variables that holds the app settings
    @Published var settings: [String: Any] = [:]

    // Initialize model
    init() {
        // Load the settings
        loadSettings()
    }
    
    // MARK: - Methods

    // Load the settings
    func loadSettings() {
        // Store the settings from UserDefaults
        let loadSettings = UserDefaults.standard.dictionary(forKey: SettingsKeys.settings.rawValue)

        if loadSettings == nil || loadSettings!.isEmpty {
            // If nil or empty, use defaults
            settings = defaults
        } else {
            // Else, use loadSettings
            settings = loadSettings!
        }
    }
    
    // Browse for the path
    func browsePath(_ key: SettingsKeys) {
        // Get the current value from UserDefaults
        guard let currentPath = settings[key.rawValue] as? String else { return }
        
        // Create an instance of NSOpenPanel
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        
        // If not emulator go there, else go here
        if key.rawValue != SettingsKeys.emulatorPath.rawValue {
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.canCreateDirectories = true
            
            // Check for user home folder path
            if currentPath.hasPrefix("~") {
                let tildePath = (currentPath as NSString).expandingTildeInPath
                openPanel.directoryURL = URL(fileURLWithPath: tildePath)
            } else {
                openPanel.directoryURL = URL(fileURLWithPath: currentPath)
            }
        } else {
            // Applications folder
            openPanel.allowedContentTypes = [.applicationBundle]
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false
        
            // Check for user home folder path
            if currentPath.hasPrefix("~") {
                let tildePath = (currentPath as NSString).expandingTildeInPath
                openPanel.directoryURL = URL(fileURLWithPath: tildePath).deletingLastPathComponent()
            } else {
                openPanel.directoryURL = URL(filePath: currentPath).deletingLastPathComponent()
            }
        }
        
        // Show the dialog and return changes
        openPanel.begin { [self] result in
            if result == .OK {
                // Store the settings in a dictionary
                settings[key.rawValue] = openPanel.url?.path
                UserDefaults.standard.set(settings, forKey: SettingsKeys.settings.rawValue)
            }
        }
    }
    
    // Reset the path
    func resetPath(_ key: SettingsKeys) {
        // Set path for the key to default path
        settings[key.rawValue] = defaults[key.rawValue]
        
        // Update the UserDefaults
        UserDefaults.standard.set(settings, forKey: SettingsKeys.settings.rawValue)
    }
    
    // Enable/Disable custom ROMs
    func toggleCustomROMs(_ customROMs: Bool) {
        if !customROMs {
            // User doesn't want custom ROMs path
            resetPath(.romsPath)
        } else {
            // If they want custom path, set the value
            UserDefaults.standard.set(settings, forKey: SettingsKeys.settings.rawValue)
        }
    }
    
    // Toggle appearance scheme
    func toggleAppearance(_ appearance: AppearanceKeys) {
        // Assign setting to dictionary
        settings[SettingsKeys.appearance.rawValue] = appearance.rawValue
        
        // Toggle theme apperance
        NSApp.appearance = NSAppearance(named: NSAppearance.Name(rawValue: appearance.rawValue))
        
        // Update the UserDefaults
        UserDefaults.standard.set(settings, forKey: SettingsKeys.settings.rawValue)
    }
}

// MARK: - Default Settings

// The application default settings
class DefaultSettings {
    // Enable shared usage
    static let shared = DefaultSettings()
    
    // Instance of default settings
    let defaults: [String: Any]
    
    // Initialize default settings
    private init() {
        defaults = [
            SettingsKeys.emulatorPath.rawValue: "/Applications/86Box.app",
            SettingsKeys.machinesPath.rawValue: ("~/Documents" as NSString).expandingTildeInPath,
            SettingsKeys.romsPath.rawValue: ("~/Library/Application Support/net.86box.86Box/roms" as NSString).expandingTildeInPath,
            SettingsKeys.customROMs.rawValue: false,
            SettingsKeys.appearance.rawValue: AppearanceKeys.none.rawValue
        ]
    }
}

// MARK: - Enum Settings

// Enumerate settings keys
enum SettingsKeys: String {
    case settings = "Settings"
    case firstRun = "First Run"
    case emulatorPath = "EmulatorPath"
    case machinesPath = "MachinesPath"
    case romsPath = "ROMsPath"
    case customROMs = "CustomROMs"
    case appearance = "Appearance"
}

// Enumerate theme settings
enum AppearanceKeys: String {
    case none = ""
    case aqua = "NSAppearanceNameAqua"
    case darkAqua = "NSAppearanceNameDarkAqua"
}

// Enumerate external links
enum extLinks: String {
    case discord = "https://discord.gg/v5fCgFw"
    case support = "https://86box.readthedocs.io/en/latest/index.html"
}
