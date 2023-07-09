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
    
    // Environment object machine library
    @EnvironmentObject var library: Library
    
    // MARK: - Properties
    
    // Default machines library path
    @AppStorage("MachinesPath") private var machinesPath: String = ""

    // MARK: - Scene
    
    var body: some View {
        // Machines list
        List {
            Section {
                ForEach(library.machines) { machine in
                    // Machine link
                    NavigationLink {
                        MachineView(machine: machine)
                    } label: {
                        // Link button
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                // Machine icon
                                machine.selectedIcon()
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
                                    Text(machine.status == .running ? "Running" : (machine.status == .stopped ? "Stopped" : "Configuring"))
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
                            library.runMachine(machine: machine)
                        }) {
                            Text("Start")
                        }
                        .disabled(machine.status == .running)
                        Divider()
                        
                        // Edit machine
                        Button(action: {
                            library.editMachine = machine
                        }) {
                            Text("Edit...")
                        }
                        .disabled(library.editMachine != nil)
                        
                        // Configure machine
                        Button(action: {
                            library.configureMachine(machine: machine)
                        }) {
                            Text("Configure...")
                        }
                        .disabled(machine.status == .configuring)
                        Divider()
                        
                        // Clone machine
                        Button(action: {
                            library.clone(machine: machine)
                        }) {
                            Text("Clone...")
                        }
                        
                        // Delete machine
                        Button(action: {
                            library.delete(machine: machine)
                        }) {
                            Text("Remove \"\(machine.name)\"...")
                        }
                        Divider()
                        
                        // Show in Finder
                        Button(action: {
                            library.find(machine: machine)
                        }) {
                            Text("Show in Finder")
                        }
                    }
                }
                // Alow user sorting of the machines list
                .onMove { indices, newOffset in
                    library.move(fromOffsets: indices, toOffset: newOffset)
                }
                // Update list on changes to path
                .onChange(of: machinesPath) { _ in
                    library.load()
                }
            } header: {
                // List header
                Text("MACHINES")
                    .padding(.vertical, 4)
            }
            .collapsible(false)
        }
    }
}

// MARK: - Preview

struct SidebarView_Previews: PreviewProvider {
    static var previews: some View {
        SidebarView()
            .environmentObject(Library())
    }
}
