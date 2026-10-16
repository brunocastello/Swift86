//
//  AppearanceSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View

// Application settings view
struct AppearanceSettingsView: View {
    
    // MARK: - Environment Objects
    
    // Environment object application settings
    @EnvironmentObject var settings: SettingsStore
    
    // MARK: - Scene
    
    var body: some View {
        Form {
            Group {
                // Appearance selection
                Picker("Appearance:", selection: $settings.config.appearance) {
                    Text("System").tag("")
                    Divider()
                    Text("Light").tag("NSAppearanceNameAqua")
                    Text("Dark").tag("NSAppearanceNameDarkAqua")
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .padding(.bottom, 10)
                .accessibilityLabel("Appearance:")
            }
            .frame(minWidth: 387)
            .onChange(of: settings.config.appearance) { theme in
                // Theme changer
                NSApp.appearance = NSAppearance(named: NSAppearance.Name(rawValue: theme))
            }
        }
        .fixedSize()
        .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
    }
}

// MARK: - Preview

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView()
            .environmentObject(SettingsStore.shared)
    }
}
