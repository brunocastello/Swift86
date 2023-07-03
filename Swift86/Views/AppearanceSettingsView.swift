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
    
    // MARK: - Properties
    @AppStorage("Appearance") private var appearance: String = ""
    
    // MARK: - Scene
    
    var body: some View {
        Form {
            Group {
                // Appearance selection
                Picker(LocalizedStringKey("Appearance:"), selection: $appearance) {
                    Text(LocalizedStringKey("System")).tag("")
                    Divider()
                    Text(LocalizedStringKey("Light")).tag("NSAppearanceNameAqua")
                    Text(LocalizedStringKey("Dark")).tag("NSAppearanceNameDarkAqua")
                }
                .pickerStyle(.menu)
                .frame(width: 200)
                .padding(.bottom, 10)
                .accessibilityLabel(LocalizedStringKey("Appearance"))
            }
            .frame(minWidth: 421)
            .onChange(of: appearance) { theme in
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
    }
}
