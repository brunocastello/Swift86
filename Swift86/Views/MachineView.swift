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
    
    // MARK: - Properties
    
    // Machine instance
    let machine: Machine?
    
    // Machine size
    @State private var machineSize: String?
    
    // MARK: - Scene
    
    // Configure needs a stopped machine, or a running one that can open its Settings
    private func configureDisabled(_ machine: Machine) -> Bool {
        switch machine.status {
        case .stopped: return false
        case .running, .paused: return !machine.isControllable
        case .configuring: return true
        }
    }
    
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
                        .disabled(machine.status != .stopped || library.isBusy(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status != .stopped || library.isBusy(machine)))
                        
                        // Machine name and status
                        VStack(alignment: .leading, spacing: 0) {
                            Text(machine.name)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                            Text(machine.status == .running ? "Running" : (machine.status == .paused ? "Paused" : (machine.status == .stopped ? "Powered Off" : "Configuring")))
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
                        .disabled(configureDisabled(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: configureDisabled(machine)))
                        
                        // Delete machine
                        Button(action: {
                            library.pendingConfirmation = .remove(machine)
                        }) {
                            Image(systemName: "trash")
                                .imageScale(.large)
                        }
                        .disabled(machine.status != .stopped || library.isBusy(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status != .stopped || library.isBusy(machine)))
                    }
                    .padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Machine description
                        Group {
                            if !machine.notes.isEmpty {
                                Text(machine.notes)
                            } else {
                                Text("Click here to add a note")
                                    .foregroundColor(.gray)
                            }
                        }
                        .panelStyle()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if machine.notes.isEmpty {
                                library.editMachine = machine
                            }
                        }

                        // Machine size
                        LabeledContent("Size", value: machineSize ?? "…")
                            .panelStyle()
                            .task(id: "\(machine.folderName)|\(machine.status)") {
                                machineSize = nil
                                let size = await sizeOf(machine.folderName)
                                guard !Task.isCancelled else { return }
                                machineSize = size
                            }
                    }
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                }
            }
            .navigationSubtitle(machine.name)
        } else {
            // Welcome view
            WelcomeView()
        }
    }
}

// MARK: - Machine Size

extension MachineView {
    // Human readable folder size, calculated off the main actor
    @MainActor
    fileprivate func sizeOf(_ name: String) async -> String {
        let url = library.machinesURL.appendingPathComponent(name)
        let bytes = await Task.detached(priority: .utility) { MachineFiles.folderSize(at: url) }.value
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Preview

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        MachineView(machine: Machine())
            .environmentObject(Library(loadsLibrary: false))
    }
}
