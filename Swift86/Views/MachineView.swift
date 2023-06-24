//
//  MachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machine Detail View

// Selected machine detail view
struct MachineView: View {
    
    // MARK: - Environment Objects
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel
    
    // Viewing machine
    let machine: Machine?

    // MARK: - Scene
    
    var body: some View {
        // Update the view, observing for excluded or updated machines.
        if let machine = machine, let machine = machineViewModel.machines.first(where: { $0 == machine }) {
            ScrollView {
                VStack(spacing: 0) {
                    // Machine header title
                    HStack {
                        // Start/Stop machine
                        Button(action: {
                            machineViewModel.runMachine(machine)
                        }) {
                            Image(systemName: "power")
                                .imageScale(.large)
                        }
                        .disabled(machine.status == .running)
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status == .running))
                        .help(Text(LocalizedStringKey("Start")))
                        
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
                            machineViewModel.machine = machine.copy()
                            machineViewModel.isShowingEditMachine.toggle()
                        }) {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                        }
                        .disabled(machineViewModel.isShowingEditMachine == true)
                        .buttonStyle(MachineButtonStyle(isDisabled: machineViewModel.isShowingEditMachine == true))
                        .help(Text(LocalizedStringKey("Edit machine")))
                        
                        // Configure machine
                        Button(action: {
                            machineViewModel.configureMachine(machine)
                        }) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                        .disabled(machineViewModel.isConfiguringMachine == true)
                        .buttonStyle(MachineButtonStyle(isDisabled: machineViewModel.isConfiguringMachine == true))
                        .help(Text(LocalizedStringKey("Configure machine")))
                        // Delete machine
                        Button(action: {
                            machineViewModel.deleteMachine(machine)
                        }) {
                            Image(systemName: "trash")
                                .imageScale(.large)
                        }
                        .buttonStyle(MachineButtonStyle(isDisabled: false))
                        .help(Text(LocalizedStringKey("Delete machine")))
                    }
                    .padding(EdgeInsets(top: 20, leading: 20, bottom: 10, trailing: 20))
                    
                    Section {
                        HStack {
                            if !machine.notes.isEmpty {
                                Text(machine.notes)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text(LocalizedStringKey("Add a note here"))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                    }
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(10)
                    .padding(EdgeInsets(top: 10, leading: 20, bottom: 0, trailing: 20))
                }
            }
            .navigationSubtitle(machine.name)
        } else {
            WelcomeView(machineViewModel: machineViewModel)
        }
    }
}

// MARK: - Preview

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        MachineView( machineViewModel: MachineViewModel(), machine: Machine())
    }
}
