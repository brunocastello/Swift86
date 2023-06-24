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
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel

    // MARK: - Scene
    
    var body: some View {
        // Machines list
        List {
            Section {
                ForEach(machineViewModel.machines) { machine in
                    // Machine item view
                    VStack(alignment: .leading, spacing: 0) {
                        // Link for machine view
                        NavigationLink(value: machine) {
                            HStack(spacing: 0) {
                                // Machine icon
                                if let nsImage = machine.icon ?? machineViewModel.defaultIcon {
                                    Image(nsImage: nsImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 30, height: 30, alignment: .center)
                                        .padding(2)
                                }
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
                        // Context menu
                        .contextMenu {
                            // Start/Stop machine
                            Button(action: {
                                machineViewModel.runMachine(machine)
                            }) {
                                Text(LocalizedStringKey("Start"))
                            }
                            .disabled(machine.status == .running)
                            Divider()
                            // Edit machine details
                            Button(action: {
                                machineViewModel.machine = machine.copy()
                                machineViewModel.isShowingEditMachine.toggle()
                            }) {
                                Text(LocalizedStringKey("Edit..."))
                            }
                            .disabled(machineViewModel.isShowingEditMachine == true)
                            // Configure machine
                            Button(action: {
                                machineViewModel.configureMachine(machine)
                            }) {
                                Text(LocalizedStringKey("Configure..."))
                            }
                            .disabled(machineViewModel.isConfiguringMachine == true)
                            Divider()
                            // Clone machine
                            Button(action: {
                                machineViewModel.cloneMachine(machine)
                            }) {
                                Text(LocalizedStringKey("Clone..."))
                            }
                            // Delete machine
                            Button(action: {
                                machineViewModel.deleteMachine(machine)
                            }) {
                                Text(LocalizedStringKey("Remove \"\(machine.name)\"..."))
                            }
                            Divider()
                            // Show in Finder
                            Button(action: {
                                machineViewModel.showInFinder(machine)
                            }) {
                                Text(LocalizedStringKey("Show in Finder"))
                            }
                        }
                    }
                }
                // Alow user sorting of the machines list
                .onMove { indices, newOffset in
                    machineViewModel.moveMachine(fromOffsets: indices, toOffset: newOffset)
                }
            } header: {
                // List header
                Text(LocalizedStringKey("MACHINES"))
                    .padding(.vertical, 4)
            }
            .collapsible(false)
        }
        .listStyle(SidebarListStyle())
        .navigationDestination(for: Machine.self) { machine in
            MachineView(machineViewModel: machineViewModel, machine: machine)
        }
    }
}

// MARK: - Preview

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView(machineViewModel: MachineViewModel())
    }
}
