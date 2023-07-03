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
    var icon: NSImage? = nil
    var notes: String = ""
        
    // Machine status
    var status: MachineStatus = .stopped
    
    // Default machine icon
    let defaultIcon: NSImage? = NSImage(systemSymbolName: "desktopcomputer", accessibilityDescription: "")
    
    // Selected machine icon
    var selectedIcon: Image {
        if iconCustom && icon != nil,
           // Custom icon
           let nsImage = icon {
            return Image(nsImage: nsImage)
        } else {
            // Default icon
            let nsImage = defaultIcon!
            return Image(nsImage: nsImage)
        }
    }
}

// MARK: - Machine Status Enumerator

// Enumerator for machine status
enum MachineStatus: String, Codable {
    case stopped
    case running
}
