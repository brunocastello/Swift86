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
    
    // Observed object machine store
    @ObservedObject var store: Store
    
    // Environment variable to dismiss the current view
    @Environment(\.presentationMode) var presentationMode
    
    // Application theme
    @Environment(\.colorScheme) var colorScheme
    
    // MARK: - Properties
    
    // Machine instance
    @State var machine: Machine
    
    // MARK: - Scene
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                // Machine name input
                Text(LocalizedStringKey("Name"))
                HStack {
                    TextField("", text: $machine.name)
                        .textFieldStyle(.squareBorder)
                        .frame(minWidth: 200)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding([.bottom], 8)
                
                // Machine notes input
                Text(LocalizedStringKey("Notes"))
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
                Text(LocalizedStringKey("Icon"))
                HStack {
                    // Thumbnail
                    machine.selectedIcon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .foregroundColor(machine.iconCustom ? Color.blue : Color.primary)
                        .onTapGesture {
                            // Icon Picker
                            iconPicker(machine: machine)
                        }
                    // Toggle default or custom icon
                    VStack {
                        // Radio Button toggle
                        Picker(selection: $machine.iconCustom, label: EmptyView()) {
                            Text(LocalizedStringKey("Default icon")).tag(false)
                            Text(LocalizedStringKey("Custom icon")).tag(true)
                        }
                        .pickerStyle(RadioGroupPickerStyle())
                    }
                    .frame(height: 50)
                    .padding(.leading, 8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
            }
            .padding()
            
            // Footer
            VStack {
                Divider()
                HStack {
                    Spacer()
                    // Cancel button
                    Button(action: {
                        // Cancel instance
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(LocalizedStringKey("Cancel"))
                            .standardStyle()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    // Save button
                    Button(action: {
                        // Check first if an icon was selected
                        if machine.iconCustom && machine.icon == nil {
                            machine.iconCustom = false
                        }

                        // Save machine and reload library
                        store.editMachine(machine: machine)
                        store.loadMachines()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(LocalizedStringKey("Save"))
                            .standardStyle()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding([.top], 8)
                .padding([.leading, .trailing, .bottom])
            }
        }
        .frame(minWidth: 480, maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // Browse for machine icon
    private func iconPicker(machine: Machine) {
        store.showIconPicker(machine: machine) { iconURL in
            // Unwrap url variable
            if let iconURL = iconURL {
                // Set selected icon
                self.machine.icon = NSImage(contentsOf: iconURL)!
            }
        }
    }
}

// MARK: - Preview

struct EditMachineView_Previews: PreviewProvider {
    static var previews: some View {
        EditMachineView(store: Store(), machine: Machine())
    }
}
