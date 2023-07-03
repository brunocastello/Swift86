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
@main struct Manager86App: App {

    // MARK: - Environment Objects
    
    // Application delegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Observed object machine store
    @StateObject private var store = Store()

    // MARK: - Scene
    
    var body: some Scene {
        // Main view
        WindowGroup {
            ContentView(store: store)
        }
        // Menu bar commands
        .commands {
            // Add new machine command
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                // Show Add machine
                Button(action: {
                    store.isShowingAddMachine.toggle()
                }) {
                    Text(LocalizedStringKey("Add machine"))
                }
                .keyboardShortcut("N", modifiers: [.command])
            }
            
            // Sidebar Toggle
            SidebarCommands()
            
            // Help Menu
            CommandGroup(replacing: .help) {
                // 86Box Documentation
                Button(action: {
                    let url = URL(string: "https://86box.readthedocs.io/en/latest/index.html")!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text(LocalizedStringKey("Documentation"))
                }).keyboardShortcut(KeyEquivalent("1"), modifiers: [.command, .control])
                
                // 86Box Discord
                Button(action: {
                    let url = URL(string: "https://discord.gg/v5fCgFw")!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text(LocalizedStringKey("86Box Discord"))
                }).keyboardShortcut(KeyEquivalent("2"), modifiers: [.command, .control])
            }
        }

        // MARK: - Settings
        
        // Settings view
        Settings {
            SettingsView()
                .navigationTitle(LocalizedStringKey("Settings"))
        }
    }
}
