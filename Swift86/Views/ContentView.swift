//
//  ContentView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Content View

// Main Content view
struct ContentView: View {
    
    // MARK: - Environment Objects
    
    // Environment object machine library
    @EnvironmentObject var library: Library
    
    // MARK: - Properties
    
    // Constant for sidebar width
    let sidebarWidth: CGFloat = 200
    
    // MARK: - Scan Alert
    
    // Title of the scan result
    private var scanTitle: String {
        library.staleEntries?.isEmpty == false ? "Remove Missing Machines?" : "Scan Complete"
    }
    
    // The scan result is shown while there is one
    private var scanAlertShown: Binding<Bool> {
        Binding(
            get: { library.staleEntries != nil },
            set: { if !$0 { library.staleEntries = nil } }
        )
    }
    
    // MARK: - Scene

    // Content view
    var body: some View {
        NavigationSplitView(
            sidebar: {
                // Sidebar view
                SidebarView()
                    .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: .infinity)
                    // Result of Scan for Machines
                    .alert(scanTitle, isPresented: scanAlertShown, presenting: library.staleEntries) { entries in
                        if entries.isEmpty {
                            Button("OK") { }
                        } else {
                            Button("Remove", role: .destructive) { library.removeStale(entries) }
                            Button("Cancel", role: .cancel) { }
                        }
                    } message: { entries in
                        Text(entries.isEmpty
                             ? "No missing machines were found."
                             : "These machines are listed in 86Box's machine list but their folders no longer exist:\n" + entries.map(\.name).joined(separator: "\n"))
                    }
            },
            detail: {
                // Machine view
                MachineView(machine: nil)
            }
        )
        // Toolbar
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Create new machine
                Button(action: {
                    library.newMachine = Machine()
                }) {
                    Label("New Machine", systemImage: "plus")
                }
                .help("New Machine")
            }
        }
        // Keep the classic opaque toolbar under the macOS 26+ design
        .toolbarBackground(.visible, for: .windowToolbar)
        .windowToolbarBackgroundVisible()
        // Add new machine
        .sheet(item: $library.newMachine) { machine in
            EditMachineView(machine: machine, isUpdating: false)
        }
        // Edit machine
        .sheet(item: $library.editMachine) { machine in
            EditMachineView(machine: machine, isUpdating: true)
        }
        // Reusable alerts for errors
        .alert(library.alertTitle, isPresented: $library.showAlert) {
            Button("OK", action: library.alertOK ?? { })
            if library.showCancel {
                Button("Cancel", role: .cancel, action: {})
            }
        } message: {
            Text(library.alertMessage)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(SettingsStore.shared)
            .environmentObject(Library(loadsLibrary: false))
    }
}

// MARK: - Helpers

extension View {
    // Force the window toolbar background to be visible (macOS 15 and later)
    @ViewBuilder
    fileprivate func windowToolbarBackgroundVisible() -> some View {
        if #available(macOS 15, *) {
            self.toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        } else {
            self
        }
    }
}
