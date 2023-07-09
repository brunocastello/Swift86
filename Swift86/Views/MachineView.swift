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
    
    // Environment object machine library
    @EnvironmentObject var library: Library
    
    // Environment variable to dismiss the current view
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Properties
    
    // Machine instance
    let machine: Machine?
    
    // Machine size
    @State private var machineSize: String?
    
    // MARK: - Scene
    
    var body: some View {
        if let machine = library.machines.first(where: { $0.id == machine?.id }) {
            ScrollView {
                VStack(spacing: 0) {
                    // Machine header title
                    HStack {
                        // Start/Stop machine
                        Button(action: {
                            library.runMachine(machine: machine)
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
                            Text(machine.status == .running ? "Running" : (machine.status == .stopped ? "Stopped" : "Configuring"))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 5)
                        
                        Spacer()
                        
                        // Edit machine details
                        Button(action: {
                            library.editMachine = machine
                        }) {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                        }
                        .disabled(library.editMachine != nil)
                        .buttonStyle(MachineButtonStyle(isDisabled: library.editMachine != nil))
                        
                        // Configure machine
                        Button(action: {
                            library.configureMachine(machine: machine)
                        }) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                        .disabled(machine.status == .configuring)
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status == .configuring))
                        
                        // Delete machine
                        Button(action: {
                            library.delete(machine: machine)
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
                                Text("Click here to add a note")
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .onTapGesture {
                            if machine.notes.isEmpty {
                                library.editMachine = machine
                            }
                        }
                        
                        Section {
                            // Machine size
                            LabeledContent("Size", value: library.sizeOf(machine: machine.name) ?? "0 KB")
                        }
                    }
                    .formStyle(.grouped)
                    .padding(.top, -8)
                }
            }
            .navigationSubtitle(machine.name)
        } else {
            // Welcome view
            WelcomeView()
        }
    }
}

// MARK: - Preview

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        MachineView(machine: Machine())
            .environmentObject(Library())
    }
}
