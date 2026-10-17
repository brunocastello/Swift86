//
//  ApplicationSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Settings View

// Application settings view
struct ApplicationSettingsView: View {

    // MARK: - Environment Objects
    
    // Environment object application settings
    @Environment(SettingsStore.self) private var settings
    
    // MARK: - Properties
    
    // Path currently being chosen in the file importer
    @State private var browseTarget: BrowseTarget?
    
    // Is the file importer showing?
    @State private var isImporterPresented = false
    
    // Paths that can be browsed
    private enum BrowseTarget {
        case emulator, machines, roms
    }

    // MARK: - Scene
    
    var body: some View {
        Form {
            // Emulator
            Group {
                // Show location
                LabeledContent("Emulator:") {
                    PathControl(path: Bindable(settings).config.emulatorPath)
                        .frame(height: 22)
                }
                .accessibilityLabel("Emulator:")
                
                HStack {
                    // Browse location
                    Button(action: {
                        browseTarget = .emulator
                        isImporterPresented = true
                    }) {
                        Text("Browse...")
                    }
                    .accessibilityLabel("Browse...")
                    
                    // Reset default location
                    Button(action: {
                        settings.config.emulatorPath = AppConfig.defaults.emulatorPath
                    }) {
                        Text("Default Path")
                    }
                    .accessibilityLabel("Default Path")
                }
                .padding(.bottom, 10)
            }
            
            // Library
            Group {
                // Show location
                LabeledContent("Machines:") {
                    PathControl(path: Bindable(settings).config.machinesPath)
                        .frame(height: 22)
                }
                .accessibilityLabel("Machines:")
                
                HStack {
                    // Browse location
                    Button(action: {
                        browseTarget = .machines
                        isImporterPresented = true
                    }) {
                        Text("Browse...")
                    }
                    .accessibilityLabel("Browse...")
                    
                    // Reset default location
                    Button(action: {
                        settings.config.machinesPath = AppConfig.defaults.machinesPath
                    }) {
                        Text("Default Path")
                    }
                    .accessibilityLabel("Default Path")
                }
                .padding(.bottom, 10)
            }
            
            // ROMs
            Group {
                // Show location
                LabeledContent("ROMs:") {
                    if settings.config.customROMs {
                        PathControl(path: Bindable(settings).config.romsPath)
                            .frame(height: 22)
                    } else {
                        Text("Default Path")
                            .foregroundColor(.gray)
                            .frame(height: 22)
                    }
                }
                .accessibilityLabel("ROMs:")
                
                HStack {
                    // Browse location
                    Button(action: {
                        browseTarget = .roms
                        isImporterPresented = true
                    }) {
                        Text("Browse...")
                    }
                    .accessibilityLabel("Browse...")
                    .disabled(!settings.config.customROMs)

                    // Reset default location
                    Button(action: {
                        // Reset path and checkbox
                        settings.config.customROMs = false
                    }) {
                        Text("Default Path")
                    }
                    .accessibilityLabel("Default Path")
                    .disabled(!settings.config.customROMs)
                }

                // Toggle visibility of this section
                Toggle(isOn: Bindable(settings).config.customROMs) {
                    Text("Customize Path")
                }
                .accessibilityLabel("Customize Path")
                .padding(.bottom, 10)
                .onChange(of: settings.config.customROMs) { _, customROMs in
                    if customROMs == false {
                        settings.config.romsPath = AppConfig.defaults.romsPath
                    }
                }
            }
        }
        .fixedSize()
        .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
        // Browse for the selected path
        .fileImporter(
            isPresented: $isImporterPresented,
            allowedContentTypes: browseTarget == .emulator ? [.applicationBundle] : [.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                // Update the matching path
                switch browseTarget {
                case .emulator: settings.config.emulatorPath = url.path
                case .machines: settings.config.machinesPath = url.path
                case .roms: settings.config.romsPath = url.path
                case nil: break
                }
            }
            browseTarget = nil
        }
        .fileDialogDefaultDirectory(startingDirectory)
    }
    
    // MARK: - Helpers
    
    // Folder the file importer opens in
    private var startingDirectory: URL? {
        switch browseTarget {
        case .emulator: return URL(filePath: settings.config.emulatorPath).deletingLastPathComponent()
        case .machines: return URL(filePath: settings.config.machinesPath)
        case .roms: return URL(filePath: settings.config.romsPath)
        case nil: return nil
        }
    }
}

// MARK: - Preview

#Preview {
    ApplicationSettingsView()
        .environment(SettingsStore.shared)
}

