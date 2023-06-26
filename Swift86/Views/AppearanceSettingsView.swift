//
//  AppearanceSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View (Appearance)

// Application appearance view
struct AppearanceSettingsView: View {
    
    // MARK: - Environment Objects
    
    // MachineViewModel observed object for machines
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    // MARK: - Scene
 
    var body: some View {
        Form {
            // Inside the Form section
            Section(header: Text(LocalizedStringKey("Appearance"))) {
                Picker(LocalizedStringKey("Appearance"), selection: Binding<AppearanceKeys>(
                    get: { AppearanceKeys(rawValue: settingsViewModel.settings[SettingsKeys.appearance.rawValue] as? String ?? "") ?? .none },
                    set: { appearance in settingsViewModel.toggleAppearance(appearance) }
                )) {
                    Text(LocalizedStringKey("System")).tag(AppearanceKeys.none)
                    Divider()
                    Text(LocalizedStringKey("Light")).tag(AppearanceKeys.aqua)
                    Text(LocalizedStringKey("Dark")).tag(AppearanceKeys.darkAqua)
                }
                .pickerStyle(.menu)
                .accessibilityLabel(LocalizedStringKey("Appearance"))
            }
        }
        .formStyle(.grouped)
        .fixedSize()
        .scrollDisabled(true)
    }
}

// MARK: - Preview

struct AppearanceSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        AppearanceSettingsView(settingsViewModel: SettingsViewModel())
    }
}

