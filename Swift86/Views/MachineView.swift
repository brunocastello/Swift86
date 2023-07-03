//
//  MachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Sidebar View

// Sidebar view
struct MachineView: View {
    
    // MARK: - Environment Objects
    
    // Observed object machine store
    @ObservedObject var store: Store
    
    // Environment variable to dismiss the current view
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Properties
    
    // machines observed object for machines
    let machine: Machine?
    
    // MARK: - Scene
    
    var body: some View {
        if let machine = machine, store.machines.contains(where: { $0.id == machine.id }) {
            ScrollView {
                VStack(spacing: 0) {
                    // Machine header title
                    HStack {
                        // Start/Stop machine
                        Button(action: {
                            store.runMachine(machine: machine)
                        }) {
                            Image(systemName: "power")
                                .imageScale(.large)
                        }
                        .disabled(machine.status == .running)
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status == .running))
                        
                        // Machine name and status
                        VStack(alignment: .leading, spacing: 0) {
                            Text(machine.name)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                            Text(machine.status == .running ? LocalizedStringKey("Running") : LocalizedStringKey("Stopped"))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 5)
                        
                        Spacer()
                        
                        // Edit machine details
                        Button(action: {
                            store.editMachine = machine
                            store.isShowingEditMachine.toggle()
                        }) {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                        }
                        .disabled(store.isShowingEditMachine == true)
                        .buttonStyle(MachineButtonStyle(isDisabled: store.isShowingEditMachine == true))
                        
                        // Configure machine
                        Button(action: {
                            store.configureMachine(machine: machine)
                        }) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                        .disabled(store.isConfiguringMachine == true)
                        .buttonStyle(MachineButtonStyle(isDisabled: store.isConfiguringMachine == true))
                        // Delete machine
                        Button(action: {
                            store.deleteMachine(machine: machine)
                        }) {
                            Image(systemName: "trash")
                                .imageScale(.large)
                        }
                        .buttonStyle(MachineButtonStyle(isDisabled: false))
                    }
                    .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
                    
                    Form {
                        Section {
                            // Machine description
                            if !machine.notes.isEmpty {
                                Text(machine.notes)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey("Add a note here"))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        
                        Section {
                            // Machine size
                            LabeledContent(LocalizedStringKey("Size"), value: store.machineSize(machine: machine.name) ?? "N/A")
                        }
                    }
                    .formStyle(.grouped)
                    .padding(.top, -8)
                }
            }
            .navigationSubtitle(machine.name)
        } else {
            // Welcome view
            WelcomeView(store: store)
        }
    }
}

// MARK: - Preview

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        MachineView(store: Store(), machine: Machine())
    }
}
