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
    @Environment(Library.self) private var library
    
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
    
    // The confirmation is shown while an action is pending
    private var confirmationShown: Binding<Bool> {
        Binding(
            get: { library.pendingConfirmation != nil },
            set: { if !$0 { library.pendingConfirmation = nil } }
        )
    }
    
    // Title of the pending confirmation
    private var confirmationTitle: String {
        switch library.pendingConfirmation {
        case .kill(let machine):
            return "Killing a virtual machine can cause data loss. Only do this if the 86Box process gets stuck.\n\nDo you really wish to kill the virtual machine \"\(machine.name)\"?"
        case .wipeNVRAM(let machine):
            return "Wiping a virtual machine's NVRAM deletes its nvr files. You'll have to reconfigure the BIOS if applicable.\n\nAre you sure you wish to wipe the NVRAM of the virtual machine \"\(machine.name)\"?"
        case .remove(let machine):
            return String(format: NSLocalizedString("Are you sure you want to delete \"%@\" permanently?", comment: ""), machine.name)
        case nil:
            return ""
        }
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
        .toolbarBackgroundVisibility(.visible, for: .windowToolbar)
        // Add new machine
        .sheet(item: Bindable(library).newMachine) { machine in
            EditMachineView(machine: machine, isUpdating: false)
        }
        // Edit machine
        .sheet(item: Bindable(library).editMachine) { machine in
            EditMachineView(machine: machine, isUpdating: true)
        }
        // Clone machine
        .sheet(item: Bindable(library).cloneSource) { machine in
            CloneMachineView(source: machine, suggestedName: library.suggestedCloneName(for: machine))
        }
        // Confirm killing, wiping or removing a machine
        .alert(confirmationTitle, isPresented: confirmationShown, presenting: library.pendingConfirmation) { confirmation in
            switch confirmation {
            case .kill(let machine):
                Button("No", role: .cancel) { }
                    .keyboardShortcut(.defaultAction)
                Button("Yes") { library.kill(machine) }
            case .wipeNVRAM(let machine):
                Button("No", role: .cancel) { }
                    .keyboardShortcut(.defaultAction)
                Button("Yes") { library.wipeNVRAM(machine) }
            case .remove(let machine):
                Button("OK", role: .destructive) { library.remove(machine) }
                Button("Cancel", role: .cancel) { }
            }
        } message: { confirmation in
            if case .remove = confirmation {
                Text(NSLocalizedString("You cannot undo this action.", comment: ""))
            }
        }
        // Reusable alerts for errors, on their own view so they never compete with the confirmation
        .background {
            Color.clear
                .alert(library.alertTitle, isPresented: Bindable(library).showAlert) {
                    Button("OK", action: library.alertOK ?? { })
                    if library.showCancel {
                        Button("Cancel", role: .cancel, action: {})
                    }
                } message: {
                    Text(library.alertMessage)
                }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(SettingsStore.shared)
        .environment(Library(loadsLibrary: false))
}

