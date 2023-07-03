//
//  ContentView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Content View

// Main Content view
struct ContentView: View {
    
    // MARK: - Environment Objects
    
    // Observed object machine store
    @ObservedObject var store: Store
    
    // MARK: - Properties
    
    // Constant for sidebar width
    let sidebarWidth: CGFloat = 200
    
    // MARK: - Scene

    // Content view
    var body: some View {
        NavigationSplitView(
            sidebar: {
                // Sidebar view
                SidebarView(store: store)
                    .navigationSplitViewColumnWidth(min: sidebarWidth, ideal: sidebarWidth, max: .infinity)
            },
            detail: {
                // Machine view
                MachineView(store: store, machine: nil)
            }
        )
        // Toolbar
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                // Add machine
                Button(action: {
                    store.isShowingAddMachine.toggle()
                }) {
                    Label("Add", systemImage: "plus")
                }
                .help(Text(LocalizedStringKey("Add Machine")))
            }
        }
        // Add machine view
        .sheet(isPresented: $store.isShowingAddMachine, onDismiss: {}) {
            AddMachineView(store: store, machine: Machine())
        }
        // Edit machine view
        .sheet(isPresented: $store.isShowingEditMachine, onDismiss: {}) {
            EditMachineView(store: store, machine: store.editMachine!)
        }
        // Reusable alerts for errors
        .alert(store.alertTitle, isPresented: $store.showAlert) {
            Button(LocalizedStringKey("OK"), action: store.okAction ?? { })
            if store.showCancelButton {
                Button(LocalizedStringKey("Cancel"), role: .cancel, action: {})
            }
        } message: {
            Text(store.alertMessage)
        }
    }
}

// MARK: - Preview

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(store: Store())
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
