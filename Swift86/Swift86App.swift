//
//  Swift86App.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - MacBoxApp

// Main struct view
@main
struct Swift86App: App {
    
    // MARK: - Environment Objects
    
    // Application delegate call
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MachineViewModel observed object for machines
    @StateObject private var settingsViewModel = SettingsViewModel()
    
    // MachineViewModel observed object for machines
    @StateObject private var machineViewModel = MachineViewModel()
    
    // Check for application first run
    @AppStorage(SettingsKeys.firstRun.rawValue) var FirstRun: Bool = false
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            // Content view
            ContentView(machineViewModel: machineViewModel)
                .onAppear {
                    // Reset UserDefaults FOR DEBUGGING ONLY!
                    // UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
                    
                    // Check if it's the first launch
                    if UserDefaults.standard.bool(forKey: SettingsKeys.firstRun.rawValue) != true {
                        // Set the flag indicating that the app has launched before
                        UserDefaults.standard.set(true, forKey: SettingsKeys.firstRun.rawValue)
                        
                        // Perform any first launch setup or logic here
                        if #available(macOS 13.0, *) {
                            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                        }
                        else {
                            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                        }
                    }
                }
        }
        // Menu bar commands
        .commands {
            // Add new machine command
            CommandGroup(replacing: CommandGroupPlacement.newItem) {
                // Show Add machine
                Button(action: {
                    machineViewModel.isShowingAddMachine.toggle()
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
                    let url = URL(string: extLinks.support.rawValue)!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text(LocalizedStringKey("Documentation"))
                }).keyboardShortcut(KeyEquivalent("1"), modifiers: [.command, .control])
                
                // 86Box Discord
                Button(action: {
                    let url = URL(string: extLinks.discord.rawValue)!
                    NSWorkspace.shared.open(url)
                }, label: {
                    Text(LocalizedStringKey("86Box Discord"))
                }).keyboardShortcut(KeyEquivalent("2"), modifiers: [.command, .control])
            }
        }
        
        // Settings View
        Settings {
            SettingsView(settingsViewModel: settingsViewModel, machineViewModel: machineViewModel)
                .navigationTitle(LocalizedStringKey("Settings"))
        }
    }
}
