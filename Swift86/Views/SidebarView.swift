//
//  SidebarView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Sidebar View

// Sidebar view
struct SidebarView: View {
    
    // MARK: - Environment Objects
    
    // Observed object machine store
    @ObservedObject var store: Store
    
    // MARK: - Properties
    
    // Default machines library path
    @AppStorage("MachinesPath") private var machinesPath: String = ""

    // MARK: - Scene
    
    var body: some View {
        // Machines list
        List {
            Section {
                ForEach(store.machines) { machine in
                    // Machine link
                    NavigationLink {
                        MachineView(store: store, machine: machine)
                    } label: {
                        // Link button
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                // Machine icon
                                machine.selectedIcon
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30, alignment: .center)
                                    .padding(2)
                                // Machine details
                                VStack(alignment: .leading) {
                                    // Machine name
                                    Text(machine.name)
                                        .font(.headline)
                                        .truncationMode(.tail)
                                        .lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    // Machine status
                                    Text(machine.status == .running ? LocalizedStringKey("Running") : LocalizedStringKey("Stopped"))
                                        .font(.caption)
                                        .lineLimit(1)
                                }
                                .padding(.leading, 7)
                            }
                        }
                    }
                    // Context menu
                    .contextMenu {
                        // Start/Stop machine
                        Button(action: {
                            store.runMachine(machine: machine)
                        }) {
                            Text(LocalizedStringKey("Start"))
                        }
                        .disabled(machine.status == .running)
                        Divider()
                        // Edit machine details
                        Button(action: {
                            store.editMachine = machine
                            store.isShowingEditMachine.toggle()
                        }) {
                            Text(LocalizedStringKey("Edit..."))
                        }
                        .disabled(store.isShowingEditMachine == true)
                        // Configure machine
                        Button(action: {
                            store.configureMachine(machine: machine)
                        }) {
                            Text(LocalizedStringKey("Configure..."))
                        }
                        .disabled(store.isConfiguringMachine == true)
                        Divider()
                        // Clone machine
                        Button(action: {
                            store.cloneMachine(machine: machine)
                        }) {
                            Text(LocalizedStringKey("Clone..."))
                        }
                        // Delete machine
                        Button(action: {
                            store.deleteMachine(machine: machine)
                        }) {
                            Text(LocalizedStringKey("Remove \"\(machine.name)\"..."))
                        }
                        Divider()
                        // Show in Finder
                        Button(action: {
                            store.showInFinder(machine: machine)
                        }) {
                            Text(LocalizedStringKey("Show in Finder"))
                        }
                    }
                }
                // Alow user sorting of the machines list
                .onMove { indices, newOffset in
                    store.moveMachine(fromOffsets: indices, toOffset: newOffset)
                }
                // Update list on changes to path
                .onChange(of: machinesPath) { _ in
                    store.loadMachines()
                }
            } header: {
                // List header
                Text(LocalizedStringKey("MACHINES"))
                    .padding(.vertical, 4)
            }
            .collapsible(false)
        }
    }
}

// MARK: - Preview

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(store: Store())
    }
}
