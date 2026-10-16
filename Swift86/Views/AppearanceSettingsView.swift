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
            VStack(alignment: .leading, spacing: 10) {
                // Appearance selection
                HStack(spacing: 6) {
                    Text("Appearance:")
                    Picker("Appearance:", selection: $settings.config.appearance) {
                        Text("System").tag("")
                        Divider()
                        Text("Light").tag("NSAppearanceNameAqua")
                        Text("Dark").tag("NSAppearanceNameDarkAqua")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                    .accessibilityLabel("Appearance:")
                }
                
                // Machine screenshot preview
                Toggle("Show machine screenshots", isOn: $settings.config.showScreenshots)
            }
            .frame(minWidth: 387, alignment: .leading)
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
