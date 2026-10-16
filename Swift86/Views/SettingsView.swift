//
//  SettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View

// Application settings view
struct SettingsView: View {
    
    // MARK: - Environment Objects
    
    // Environment object application settings
    @Environment(SettingsStore.self) private var settings
    
    // MARK: - Settings Tabs
    
    // Selected tab
    @State private var selection = Tabs.general
    
    // Enumerate tabs
    private enum Tabs: Hashable {
        case general, appearance
    }
    
    // MARK: - Scene
    
    var body: some View {
        // Settings tabs
        TabView(selection: $selection) {
            // General tab
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(Tabs.general)
            // Appearance tab
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(Tabs.appearance)
        }
        .onDisappear {
            // Reset ROMs path and checkbox if same as default after Settings window close
            if settings.config.customROMs && settings.config.romsPath == AppConfig.defaults.romsPath {
                settings.config.customROMs = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .environment(SettingsStore.shared)
}
