//
//  GeneralSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View (General)

// Application settings view
struct GeneralSettingsView: View {
    
    // MARK: - Environment Objects
    
    // MachineViewModel observed object for machines
    @ObservedObject var settingsViewModel: SettingsViewModel
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel
    
    // MARK: - Scene
 
    var body: some View {
        Form {
            // Emulator Location
            Section(header: Text(LocalizedStringKey("Emulator Location"))) {
                // Emulator Path
                PathControl(path: Binding<String?>(
                    get: { settingsViewModel.settings[SettingsKeys.emulatorPath.rawValue] as? String },
                    set: { settingsViewModel.settings[SettingsKeys.emulatorPath.rawValue] = $0 }
                ))
                .frame(height: 22)
                
                HStack {
                    Spacer()
                    // Browse for path
                    Button(action: {
                        settingsViewModel.browsePath(.emulatorPath)
                    }) {
                        Text(LocalizedStringKey("Browse..."))
                    }
                    .accessibilityLabel(LocalizedStringKey("Browse..."))
                    // Reset default location
                    Button(action: {
                        settingsViewModel.resetPath(.emulatorPath)
                    }) {
                        Text(LocalizedStringKey("Default Location"))
                    }
                    .accessibilityLabel(LocalizedStringKey("Default Location"))
                }
            }
                        
            // Machines Library Location
            Section(header: Text(LocalizedStringKey("Machine Library Location"))) {
                // Machines Path
                PathControl(path: Binding<String?>(
                    get: { settingsViewModel.settings[SettingsKeys.machinesPath.rawValue] as? String },
                    set: { settingsViewModel.settings[SettingsKeys.machinesPath.rawValue] = $0 }
                ))
                .frame(height: 22)
                .onChange(of: settingsViewModel.settings[SettingsKeys.machinesPath.rawValue] as? String) { _ in
                    // Reload machine library
                    machineViewModel.loadMachines()
                }
                
                HStack {
                    Spacer()
                    // Browse for path
                    Button(action: {
                        settingsViewModel.browsePath(.machinesPath)
                    }) {
                        Text(LocalizedStringKey("Browse..."))
                    }
                    .accessibilityLabel(LocalizedStringKey("Browse..."))
                    // Reset default location
                    Button(action: {
                        settingsViewModel.resetPath(.machinesPath)
                    }) {
                        Text(LocalizedStringKey("Default Location"))
                    }
                    .accessibilityLabel(LocalizedStringKey("Default Location"))
                }
            }
            
            // ROMs Library Location
            Section(header: Text(LocalizedStringKey("ROMs Location"))) {
                // Toggle visibility of this section
                Toggle(isOn: Binding<Bool>(
                    get: { settingsViewModel.settings[SettingsKeys.customROMs.rawValue] as? Bool ?? false },
                    set: { settingsViewModel.settings[SettingsKeys.customROMs.rawValue] = $0 }
                )) {
                    Text(LocalizedStringKey("Enable Custom ROMs"))
                }
                .onChange(of: settingsViewModel.settings[SettingsKeys.customROMs.rawValue] as? Bool) { customROMs in
                    // User Custom ROMs choice
                    settingsViewModel.toggleCustomROMs(customROMs!)
                }

                // ROMs Path
                if settingsViewModel.settings[SettingsKeys.customROMs.rawValue] as? Bool == true {
                    PathControl(path: Binding<String?>(
                        get: { settingsViewModel.settings[SettingsKeys.romsPath.rawValue] as? String },
                        set: { settingsViewModel.settings[SettingsKeys.romsPath.rawValue] = $0 }
                    )).frame(height: 22)
                    
                    HStack {
                        Spacer()
                        // Browse for path
                        Button(action: {
                            settingsViewModel.browsePath(.romsPath)
                        }) {
                            Text(LocalizedStringKey("Browse..."))
                        }
                        .accessibilityLabel(LocalizedStringKey("Browse..."))
                        // Reset default location
                        Button(action: {
                            settingsViewModel.settings[SettingsKeys.customROMs.rawValue] = false
                        }) {
                            Text(LocalizedStringKey("Default Location"))
                        }
                        .accessibilityLabel(LocalizedStringKey("Default Location"))
                    }
                } else {
                    Text(LocalizedStringKey("Default ROMs location"))
                        .foregroundColor(.gray)
                }
            }
        }
        .formStyle(.grouped)
        .fixedSize()
        .scrollDisabled(true)
    }
}

// MARK: - Preview

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView(settingsViewModel: SettingsViewModel(), machineViewModel: MachineViewModel())
    }
}

