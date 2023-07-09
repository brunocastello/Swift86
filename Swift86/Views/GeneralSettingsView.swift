//
//  GeneralSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View

// Application settings view
struct GeneralSettingsView: View {

    // MARK: - Environment Objects
    
    // Environment object application settings
    @EnvironmentObject var appSettings: AppSettings
    
    // MARK: - Properties
    @AppStorage("EmulatorPath") private var emulatorPath: String = ""
    @AppStorage("MachinesPath") private var machinesPath: String = ""
    @AppStorage("RomsPath") private var romsPath: String = ""
    @AppStorage("CustomROMs") private var customROMs: Bool = false

    // MARK: - Scene
    
    var body: some View {
        Form {
            // Emulator
            Group {
                // Show location
                LabeledContent(LocalizedStringKey("Emulator Location:")) {
                    PathControl(path: $emulatorPath)
                        .frame(height: 22)
                }
                .accessibilityLabel(LocalizedStringKey("Emulator Location"))
                
                HStack {
                    // Browse location
                    Button(action: {
                        appSettings.browsePath(path: emulatorPath, key: "EmulatorPath")
                    }) {
                        Text(LocalizedStringKey("Browse..."))
                    }
                    .accessibilityLabel(LocalizedStringKey("Browse..."))
                    // Reset default location
                    Button(action: {
                        UserDefaults.standard.set(appSettings.emulatorPath, forKey: "EmulatorPath")
                    }) {
                        Text(LocalizedStringKey("Default Location"))
                    }
                    .accessibilityLabel(LocalizedStringKey("Default Location"))
                }
                .padding(.bottom, 10)
            }
            
            // Library
            Group {
                // Show location
                LabeledContent(LocalizedStringKey("Library Location:")) {
                    PathControl(path: $machinesPath)
                        .frame(height: 22)
                }
                .accessibilityLabel(LocalizedStringKey("Library Location"))
                
                HStack {
                    // Browse location
                    Button(action: {
                        appSettings.browsePath(path: machinesPath, key: "MachinesPath")
                    }) {
                        Text(LocalizedStringKey("Browse..."))
                    }
                    .accessibilityLabel(LocalizedStringKey("Browse..."))
                    // Reset default location
                    Button(action: {
                        UserDefaults.standard.set(appSettings.machinesPath, forKey: "MachinesPath")
                    }) {
                        Text(LocalizedStringKey("Default Location"))
                    }
                    .accessibilityLabel(LocalizedStringKey("Default Location"))
                }
                .padding(.bottom, 10)
            }
            
            // ROMs
            Group {
                // Show location
                LabeledContent(LocalizedStringKey("ROMs Location:")) {
                    if customROMs {
                        PathControl(path: $romsPath)
                            .frame(height: 22)
                    } else {
                        Text(LocalizedStringKey("Default ROMs Location"))
                            .foregroundColor(.gray)
                            .frame(height: 22)
                    }
                }
                .accessibilityLabel(LocalizedStringKey("ROMs Location"))
                
                HStack {
                    // Browse location
                    Button(action: {
                        appSettings.browsePath(path: romsPath, key: "RomsPath")
                    }) {
                        Text(LocalizedStringKey("Browse..."))
                    }
                    .accessibilityLabel(LocalizedStringKey("Browse..."))
                    .disabled(!customROMs)

                    // Reset default location
                    Button(action: {
                        // Reset path and checkbox
                        UserDefaults.standard.set(appSettings.customROMs, forKey: "CustomROMs")
                    }) {
                        Text(LocalizedStringKey("Default Location"))
                    }
                    .accessibilityLabel(LocalizedStringKey("Default Location"))
                    .disabled(!customROMs)
                }

                // Toggle visibility of this section
                Toggle(isOn: $customROMs) {
                    Text(LocalizedStringKey("Enable Custom ROMs"))
                }
                .accessibilityLabel(LocalizedStringKey("Enable Custom ROMs"))
                .padding(.bottom, 10)
                .onChange(of: customROMs) { customROMs in
                    if customROMs == false {
                        UserDefaults.standard.set(appSettings.romsPath, forKey: "RomsPath")
                    }
                }
            }
        }
        .fixedSize()
        .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
            // Reset ROMs path and checkbox if same as default after Settings window close
            if let window = notification.object as? NSWindow, window.identifier?.rawValue == "com_apple_SwiftUI_Settings_window",
               romsPath == UserDefaults.standard.object(forKey: "RomsPath") as! String, customROMs == true {
                UserDefaults.standard.set(appSettings.customROMs, forKey: "CustomROMs")
           }
        }
    }
}

// MARK: - Preview

struct GeneralSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralSettingsView()
    }
}
