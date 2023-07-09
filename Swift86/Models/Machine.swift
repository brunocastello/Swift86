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
    var id = UUID()
    var name: String = ""
    var iconCustom: Bool = false
    var icon: String = ""
    var notes: String = ""
        
    // Machine status
    var status: MachineStatus = .stopped
    
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
enum MachineStatus: String, Codable {
    case stopped
    case running
    case configuring
}
