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
                    Label(LocalizedStringKey("General"), systemImage: "gearshape")
                }
                .tag(Tabs.general)
            // Appearance tab
            AppearanceSettingsView()
                .tabItem {
                    Label(LocalizedStringKey("Appearance"), systemImage: "paintbrush")
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
