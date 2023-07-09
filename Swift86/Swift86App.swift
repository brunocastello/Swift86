//
//  Swift86App.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Swift86App Entry Point

// App main struct view
@main struct Swift86App: App {

    // MARK: - Environment Objects
    
    // Application delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Observed object machine library
    @StateObject var library = Library()

    // MARK: - Scene
    
    var body: some Scene {
        // Main view
        WindowGroup {
            ContentView()
                .environmentObject(library)
        }
        // Menu bar commands
        .commands {
            // Add new machine command
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                // Create new machine
                Button(action: {
                    library.newMachine = Machine()
                }) {
                    Text("New Machine")
                }
                .keyboardShortcut("N", modifiers: [.command])
            }
            
            // Sidebar Toggle
            SidebarCommands()
            
            // Help Menu
            CommandGroup(replacing: .help) {
                // 86Box Documentation
                Button(action: {
                    let url = URL(string: WebLinks.support.rawValue)!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text("Documentation")
                }).keyboardShortcut(KeyEquivalent("1"), modifiers: [.command, .control])
                
                // 86Box Discord
                Button(action: {
                    let url = URL(string: WebLinks.discord.rawValue)!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text("86Box Discord")
                }).keyboardShortcut(KeyEquivalent("2"), modifiers: [.command, .control])
            }
        }

        // MARK: - Settings
        
        // Settings view
        Settings {
            SettingsView()
                .navigationTitle("Settings")
        }
    }
}
