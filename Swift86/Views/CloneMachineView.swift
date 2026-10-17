//
//  CloneMachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 16/10/26.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Clone Machine View

// Clone machine view
struct CloneMachineView: View {
    
    // MARK: - Environment Objects
    
    // Environment object machine library
    @Environment(Library.self) private var library
    
    // Environment variable to dismiss the current view
    @Environment(\.dismiss) var dismiss
    
    // MARK: - Properties
    
    // Machine being cloned
    let source: Machine
    
    // Name of the clone
    @State private var name: String
    
    // Error from the last clone attempt, shown under the field
    @State private var error: String?
    
    // True while the folder is being copied
    @State private var isCloning = false
    
    init(source: Machine, suggestedName: String) {
        self.source = source
        _name = State(initialValue: suggestedName)
    }
    
    // MARK: - Scene
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                // Machine name input
                Text("Name:")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        TextField("", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .frame(minWidth: 200)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .disabled(isCloning)
                    }
                    
                    // Inline error
                    if let error {
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding()
            
            // Footer
            VStack {
                Divider()
                HStack {
                    // Progress while copying
                    if isCloning {
                        ProgressView()
                            .controlSize(.small)
                        Text("Cloning…")
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    // Cancel button
                    Button("Cancel", role: .cancel) {
                        // Dismiss view
                        dismiss()
                    }
                    .keyboardShortcut(.cancelAction)
                    .disabled(isCloning)
                    
                    // Clone button
                    Button("Clone") {
                        clone()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCloning)
                    .keyboardShortcut(.defaultAction)
                }
                .padding([.top], 8)
                .padding([.leading, .trailing, .bottom])
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
        .interactiveDismissDisabled(isCloning)
        .onChange(of: name) { _, _ in
            // Any later edit clears the error
            error = nil
        }
    }
    
    // MARK: - Helpers
    
    // Copy the machine, keeping the sheet open on failure
    private func clone() {
        error = nil
        isCloning = true
        Task {
            do {
                try await library.clone(source, as: name)
                dismiss()
            } catch let cloneError {
                error = cloneError.localizedDescription
                isCloning = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CloneMachineView(source: Machine(), suggestedName: "Machine copy")
        .environment(Library(loadsLibrary: false))
}
