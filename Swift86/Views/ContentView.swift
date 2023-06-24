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
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel
    
    // Constant for sidebar width
    let sidebarWidth: CGFloat = 200
    
    // MARK: - Scene

    // Content view
    var body: some View {
        NavigationSplitView(
            sidebar: {
                // Sidebar view
                SidebarView(machineViewModel: machineViewModel)
                    .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: .infinity)
            },
            detail: {
                // Welcome view
                MachineView(machineViewModel: machineViewModel, machine: nil)
            }
        )
        // Toolbar
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Add machine
                Button(action: {
                    machineViewModel.isShowingAddMachine.toggle()
                }) {
                    Label("Add", systemImage: "plus")
                }
                .help(Text(LocalizedStringKey("Add Machine")))
            }
        }
        // Add machine view
        .sheet(isPresented: $machineViewModel.isShowingAddMachine, onDismiss: {}) {
            AddMachineView(machineViewModel: machineViewModel)
        }
        // Edit machine view
        .sheet(isPresented: $machineViewModel.isShowingEditMachine, onDismiss: {}) {
            EditMachineView(machineViewModel: machineViewModel)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(machineViewModel: MachineViewModel())
    }
}
