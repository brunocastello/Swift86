//
//  AppDelegate.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Application Delegate

// Application delegate
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Methods
    
    // Function called when the application has finished launching
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disables the automatic tabbing behavior for windows
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Set default values for UserDefaults
        let settings: [String: Any] = [
            "EmulatorPath": "/Applications/86Box.app",
            "MachinesPath": ("~/Documents" as NSString).expandingTildeInPath,
            "RomsPath": ("~/Library/Application Support/net.86box.86Box/roms" as NSString).expandingTildeInPath,
            "CustomROMs": false,
            "Appearance": ""
        ]

        // Check if any of the keys in the settings dictionary is empty and update its value if necessary
        for (key, value) in settings {
            if UserDefaults.standard.object(forKey: key) == nil {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
        
        // Register default values for UserDefaults
        UserDefaults.standard.register(defaults: settings)
        
        // Set application user appearance preference
        if let theme = UserDefaults.standard.object(forKey: "Appearance") as? String {
            NSApp.appearance = NSAppearance(named: NSAppearance.Name(rawValue: theme))
        }
    }
    
    // Function called when the application becomes active
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.mainWindow?.makeKeyAndOrderFront(self)
    }
    
    // Function to terminate the application after last window closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
