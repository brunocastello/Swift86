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
    @StateObject private var appSettings = AppSettings()
    
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
                .environmentObject(appSettings)
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
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
