//
//  AddMachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Add Machine View

// Add machine view
struct AddMachineView: View {
    
    // MARK: - Environment Objects
    
    // MachineViewModel observed object for machines
    @ObservedObject var machineViewModel: MachineViewModel
    
    // Environment variable to dismiss the current view
    @Environment(\.presentationMode) var presentationMode
    
    init(machineViewModel: MachineViewModel) {
        self.machineViewModel = machineViewModel
    }
    
    // MARK: - Scene
    
    var body: some View {
        VStack {
            VStack(alignment: .leading) {
                // Machine name input
                Text(LocalizedStringKey("Name"))
                HStack {
                    TextField("", text: $machineViewModel.machine.name)
                        .textFieldStyle(.squareBorder)
                        .frame(minWidth: 200)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding([.bottom], 8)
                
                // Machine notes input
                Text(LocalizedStringKey("Notes"))
                HStack {
                    TextEditor(text: $machineViewModel.machine.notes)
                        .textFieldStyle(.squareBorder)
                        .padding(.vertical, 5)
                        .frame(minWidth: 200, minHeight: 100)
                        .lineLimit(4)
                        .border(Color(.darkGray), width: 1)
                }
                .padding([.bottom], 8)
                
                // Machine icon thumbnail
                Text(LocalizedStringKey("Icon"))
                HStack {
                    // Thumbnail
                    machineViewModel.selectedIcon
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .foregroundColor(machineViewModel.machine.iconCustom ? Color.blue : Color.primary)
                            .onTapGesture {
                                // Icon Picker
                                machineViewModel.iconPicker()
                            }
                    // Toggle default or custom icon
                    VStack {
                        // Radio Button toggle
                        Picker(selection: $machineViewModel.machine.iconCustom, label: EmptyView()) {
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
                        // Reset machine instance
                        machineViewModel.machine = Machine()
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text(LocalizedStringKey("Cancel"))
                            .standardStyle()
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    // Save button
                    Button(action: {
                        // Save new machine
                        machineViewModel.addNewMachine()
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
        .onAppear {
            machineViewModel.customIcon = machineViewModel.machine.icon
        }
    }
}

// MARK: - Preview

struct AddMachineView_Previews: PreviewProvider {
    static var previews: some View {
        AddMachineView(machineViewModel: MachineViewModel())
    }
}
