//
//  AppSettings.swift
//  Swift86
//
//  Created by Bruno Castelló on 06/07/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings Model

// The application default settings
class AppSettings: ObservableObject {
    
    // MARK: - Properties
    
    // Settings default properties
    @Published var emulatorPath: String = "/Applications/86Box.app"
    @Published var machinesPath: String = ("~/Documents" as NSString).expandingTildeInPath
    @Published var romsPath: String = ("~/Library/Application Support/net.86box.86Box/roms" as NSString).expandingTildeInPath
    @Published var customROMs: Bool = false
    @Published var appearance: String = ""
    
    // Share them across the app
    static let shared = AppSettings()
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Methods

    // Show panel to browse for the paths
    func browsePath(path: String, key: String) {
        // Create an instance of NSOpenPanel
        let openPanel = NSOpenPanel()
        openPanel.allowsMultipleSelection = false
        
        // If emulator key do this, else continue
        if key == "EmulatorPath" {
            // Applications folder
            openPanel.allowedContentTypes = [.applicationBundle]
            openPanel.canChooseFiles = true
            openPanel.canChooseDirectories = false

            // Check for user home folder tilde path
            let url = URL(filePath: path)
            if url.path.hasPrefix("~") {
                _ = (url.path as NSString).expandingTildeInPath
                openPanel.directoryURL = URL(filePath: url.path).deletingLastPathComponent()
            } else {
                openPanel.directoryURL = URL(filePath: url.path).deletingLastPathComponent()
            }
        } else {
            // Other folders
            openPanel.canChooseDirectories = true
            openPanel.canChooseFiles = false
            openPanel.canCreateDirectories = true
            
            // Check for user home folder tilde path
            let url = URL(filePath: path)
            if url.path.hasPrefix("~") {
                _ = (url.path as NSString).expandingTildeInPath
                openPanel.directoryURL = URL(filePath: url.path)
            } else {
                openPanel.directoryURL = URL(filePath: url.path)
            }
        }
        
        // Present an NSOpenPanel for user to select a new path
        openPanel.begin { response in
            if response == .OK {
                // Get the selected URL and update UserDefaults
                if let url = openPanel.url {
                    UserDefaults.standard.set(url.path, forKey: key)
                }
            }
        }
    }
}

// MARK: - External links

// Enumerate external links
enum WebLinks: String {
    case discord = "https://discord.86box.net"
    case support = "https://86box.readthedocs.io/en/latest/index.html"
}
