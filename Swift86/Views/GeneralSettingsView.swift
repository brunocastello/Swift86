//
//  GeneralSettingsView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Settings View

// General settings view
struct GeneralSettingsView: View {

    // MARK: - Environment Objects
    
    // Environment object application settings
    @Environment(SettingsStore.self) private var settings
    
    // Environment object software updater
    @Environment(Updater.self) private var updater

    // MARK: - Scene
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 10) {
                // Updates
                Toggle(isOn: Bindable(updater).automaticallyChecks) {
                    Text("Check for Updates")
                }
                .accessibilityLabel("Check for Updates")
                
                // Machine screenshot preview
                Toggle("Show machine screenshots", isOn: Bindable(settings).config.showScreenshots)
            }
        }
        .fixedSize()
        .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
    }
}

// MARK: - Preview

#Preview {
    GeneralSettingsView()
        .environment(SettingsStore.shared)
        .environment(Updater())
}
