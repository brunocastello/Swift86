//
//  Machine.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machine Model

// Model for the machine properties
struct Machine: Identifiable {

    // MARK: - Single Machine Properties
    
    // Machine properties
    // In-memory only, never persisted: the folder name is the persistent identity
    var id = UUID()
    // Display name: vmm.ini display_name, else the folder name
    var name: String = ""
    // Folder inside the machines folder, used for paths, -P and the sidebar order
    var folderName: String = ""
    // True when the vmm.ini icon is an image file that loads
    var iconCustom: Bool = false
    var icon: String = ""
    var notes: String = ""
        
    // Machine status
    var status: MachineStatus = .stopped
    // True once the running 86Box has connected to the manager socket
    var isControllable: Bool = false
    
    // Default machine icon
    let defaultIcon: Image = Image(systemName: "desktopcomputer")
    
    // Selected machine icon
    func selectedIcon() -> Image {
        if iconCustom && !icon.isEmpty,
           let nsImage = NSImage(contentsOfFile: icon) {
           // Custom icon
            return Image(nsImage: nsImage)
        } else {
            // Default icon
            return defaultIcon
        }
    }
}

// MARK: - Machine Status Enumerator

// Enumerator for machine status
enum MachineStatus: String {
    case stopped
    case running
    case paused
    case configuring
}
