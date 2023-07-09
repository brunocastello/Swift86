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
    @EnvironmentObject var library: Library
    
    // Environment variable to dismiss the current view
    @Environment(\.presentationMode) var presentationMode
    
    // Application theme
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Properties
    
    // Machine instance
    @State var machine: Machine
    
    // Editing or creating machine?
    @State var isUpdating: Bool = false
    
    // MARK: - Scene
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading) {
                // Machine name input
                Text("Name:")
                HStack {
                    TextField("", text: $machine.name)
                        .textFieldStyle(.squareBorder)
                        .frame(minWidth: 200)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
                        .background(colorScheme == .dark ? Color(NSColor.windowBackgroundColor).opacity(0.5) : Color(.clear))
                }
                .padding([.bottom], 8)
            
                // Machine icon thumbnail
                Text("Icon:")
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
                                library.iconPicker(machine: machine) { iconURL in
                                    if let iconURL = iconURL { self.machine.icon = iconURL.path }
                                }
                            }
                    }
                    .background(Color(NSColor.windowBackgroundColor))
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
            }
            .padding()
            
            // Footer
            VStack {
                Divider()
                HStack {
                    Spacer()
                    // Cancel button
                    Button(action: {
                        // Dismiss view
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                            .standardStyle()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    // Save button
                    Button(action: {
                        // Update or create?
                        if isUpdating {
                            // Update machine
                            library.edit(machine: machine)
                        } else {
                            // Create machine
                            library.create(machine: machine)
                        }
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Save")
                            .standardStyle()
                    }
                    .disabled(machine.name.isEmpty)
                    .keyboardShortcut(.defaultAction)
                }
                .padding([.top], 8)
                .padding([.leading, .trailing, .bottom])
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - TextField Extension

// Extend NSTextView for custom text fields
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            backgroundColor = .clear
            drawsBackground = true
        }
    }
}

// MARK: - Preview

struct EditMachineView_Previews: PreviewProvider {
    static var previews: some View {
        EditMachineView(machine: Machine())
    }
}
