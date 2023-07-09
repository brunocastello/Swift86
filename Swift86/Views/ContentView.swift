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
    
    // MARK: - Scene

    // Content view
    var body: some View {
        NavigationSplitView(
            sidebar: {
                // Sidebar view
                SidebarView()
                    .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: .infinity)
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
                .help(LocalizedStringKey("New Machine"))
            }
        }
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
            Button(LocalizedStringKey("OK"), action: library.alertOK ?? { })
            if library.showCancel {
                Button(LocalizedStringKey("Cancel"), role: .cancel, action: {})
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
            .environmentObject(Library())
    }
}
