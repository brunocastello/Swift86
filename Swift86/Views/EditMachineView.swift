//
//  EditMachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Add Machine View

// Add machine view
struct EditMachineView: View {
    
    // MARK: - Environment Objects
    
    // Environment object machine library
    @Environment(Library.self) private var library
    
    // Environment variable to dismiss the current view
    @Environment(\.dismiss) var dismiss
    
    // Application theme
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Properties
    
    // Machine instance
    @State var machine: Machine
    
    // Editing or creating machine?
    @State var isUpdating: Bool = false
    
    // Error from the last save attempt, shown inline under the field it relates to
    enum ErrorField { case name, icon, general }
    struct FieldError {
        let field: ErrorField
        let message: String
        // Edits at the time of the error, so only a later edit clears it
        let snapshot: String
    }
    @State private var error: FieldError?
    
    // Icon file importer
    @State private var showIconImporter = false
    
    // MARK: - Scene
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                // Machine name input
                Text("Name:")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("", text: $machine.name)
                            .textFieldStyle(.squareBorder)
                            .frame(minWidth: 200)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    errorText(for: .name)
                }
                .padding([.bottom], 8)
                
                // Machine notes input
                Text("Notes:")
                HStack {
                    TextEditor(text: $machine.notes)
                        .textFieldStyle(.squareBorder)
                        .padding(.vertical, 5)
                        .frame(minWidth: 200, minHeight: 100)
                        .lineLimit(4)
                        .border(colorScheme == .dark ? Color(.darkGray).opacity(0.5) : Color(.darkGray).opacity(0.25), width: 0.5)
                        .scrollContentBackground(.hidden)
                        .background(colorScheme == .dark ? AnyShapeStyle(.background.opacity(0.5)) : AnyShapeStyle(Color.clear))
                }
                .padding([.bottom], 8)
            
                // Machine icon thumbnail
                Text("Icon:")
                VStack(alignment: .leading, spacing: 4) {
                HStack {
                    // Thumbnail
                    VStack {
                        machine.selectedIcon()
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(machine.iconCustom ? Color.blue : Color.primary)
                            .padding(12)
                            .onTapGesture {
                                // Icon Picker
                                if machine.iconCustom { showIconImporter = true }
                            }
                    }
                    .background(Color.tileBackground)
                    .cornerRadius(8)
                    
                    // Toggle default or custom icon
                    VStack {
                        // Radio Button toggle
                        Picker(selection: $machine.iconCustom, label: EmptyView()) {
                            Text("Default icon").tag(false)
                            Text("Custom icon").tag(true)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                    }
                    .padding(.leading, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                errorText(for: .icon)
                }
            }
            .padding()
            
            // Inline error
            if let message = shownError(for: .general) {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.leading, .trailing, .bottom])
            }
            
            // Footer
            VStack {
                Divider()
                HStack {
                    Spacer()
                    // Cancel button
                    Button(action: {
                        // Dismiss view
                        dismiss()
                    }) {
                        Text("Cancel")
                            .standardStyle()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    // Save button
                    Button(action: {
                        let nameBeforeSave = library.machines.first { $0.id == machine.id }?.name
                        do {
                            // Update or create?
                            if isUpdating {
                                // Update machine
                                try library.update(machine)
                            } else {
                                // Create machine
                                try library.create(machine)
                            }
                            dismiss()
                        } catch let saveError {
                            // Keep the sheet open and show the error
                            // After a rename that went through, re-sync with what is on disk so a retry starts from the truth
                            if isUpdating, let current = library.machines.first(where: { $0.id == machine.id }),
                               current.name != nameBeforeSave {
                                machine.name = current.name
                                machine.icon = current.icon
                                machine.iconCustom = current.iconCustom
                            }
                            error = FieldError(field: field(for: saveError), message: saveError.localizedDescription, snapshot: editSnapshot)
                        }
                    }) {
                        Text("Save")
                            .standardStyle()
                    }
                    .disabled(machine.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || renameBlocked)
                    .keyboardShortcut(.defaultAction)
                }
                .padding([.top], 8)
                .padding([.leading, .trailing, .bottom])
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: editSnapshot) { _, snapshot in
            // Any later edit clears the error
            if error?.snapshot != snapshot { error = nil }
        }
        .fileImporter(isPresented: $showIconImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                machine.icon = url.path
                machine.iconCustom = true
            }
        }
        .fileDialogDefaultDirectory(iconStartingDirectory)
    }
    
    // MARK: - Helpers
    
    // Live status of the machine being edited
    private var liveStatus: MachineStatus? {
        library.machines.first { $0.id == machine.id }?.status
    }
    
    // Renaming a machine that is not stopped
    private var renameBlocked: Bool {
        guard isUpdating, let status = liveStatus, status != .stopped,
              let original = library.machines.first(where: { $0.id == machine.id }) else { return false }
        return machine.name != original.name && machine.name.trimmingCharacters(in: .whitespacesAndNewlines) != original.name
    }
    
    // Current edits, to tell when an error is out of date
    private var editSnapshot: String {
        "\(machine.name)|\(machine.icon)|\(machine.iconCustom)|\(machine.notes)"
    }
    
    // Field an error belongs to
    private func field(for error: Error) -> ErrorField {
        switch error as? Library.MachineError {
        case .invalidName, .machineRunning: return .name
        case .invalidIcon: return .icon
        default: return .general
        }
    }
    
    // Message to show for a field
    private func shownError(for field: ErrorField) -> String? {
        if field == .name && renameBlocked { return Library.MachineError.machineRunning.errorDescription }
        return error?.field == field ? error?.message : nil
    }
    
    // Red message under a field
    @ViewBuilder
    private func errorText(for field: ErrorField) -> some View {
        if let message = shownError(for: field) {
            Text(message)
                .font(.callout)
                .foregroundColor(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    // Folder the icon importer opens in
    private var iconStartingDirectory: URL {
        // Start next to the current icon
        if !machine.icon.isEmpty {
            return URL(fileURLWithPath: machine.icon).deletingLastPathComponent()
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }
}


// MARK: - Preview

#Preview {
    EditMachineView(machine: Machine())
        .environment(Library(loadsLibrary: false))
}
