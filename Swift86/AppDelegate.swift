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
    
    // Function to set the application appearance
    func applicationShouldSetAppearance() {
        // Retrieve the theme preference from UserDefaults
        if let settings = UserDefaults.standard.dictionary(forKey: SettingsKeys.settings.rawValue),
           let appearance = settings[SettingsKeys.appearance.rawValue] as? String,
           let appearanceValue = AppearanceKeys(rawValue: appearance) {
            // Set the appearance based on the selected theme
            NSApp.appearance = NSAppearance(named: NSAppearance.Name(rawValue: appearanceValue.rawValue))
        }
    }

    // Function called when the application has finished launching
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Disables the automatic tabbing behavior for windows
        NSWindow.allowsAutomaticWindowTabbing = false

        // Set application appearance
        applicationShouldSetAppearance()
    }
    
    // Function called when the application becomes active
    func applicationDidBecomeActive(_ notification: Notification) {
        // NSApp.mainWindow?.makeKeyAndOrderFront(self)
    }
    
    // Function to terminate the application after last window closed
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}
