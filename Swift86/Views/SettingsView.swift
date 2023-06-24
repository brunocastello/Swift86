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
    
    // MachineViewModel observed object for machines
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel
    
    // MARK: - Scene
 
    var body: some View {
        TabView {
            // General settings tab
            GeneralSettingsView(settingsViewModel: settingsViewModel, machineViewModel: machineViewModel)
                .tabItem {
                    Label(LocalizedStringKey("General"), systemImage: "gearshape")
                }
            // Appearance settings tab
            AppearanceSettingsView(settingsViewModel: settingsViewModel)
                .tabItem {
                    Label(LocalizedStringKey("Appearance"), systemImage: "paintbrush")
                }
        }
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(settingsViewModel: SettingsViewModel(), machineViewModel: MachineViewModel())
    }
}
