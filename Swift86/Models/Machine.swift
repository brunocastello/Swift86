//
//  Machine.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machine model

// Model for the machine properties
class Machine: ObservableObject, Identifiable, Hashable, Equatable {
    
    // MARK: - Properties
    
    // Machine properties
    var id = UUID()
    var name: String
    var iconCustom: Bool
    var icon: NSImage?
    var notes: String
    var status: MachineStatus = .stopped
    
    // MARK: - Identifiable
    
    // Initialize model
    init(
        id: UUID = UUID(),
        name: String = "",
        iconCustom: Bool = false,
        icon: NSImage? = nil,
        notes: String = "",
        status: MachineStatus = .stopped
    ) {
        self.id = id
        self.name = name
        self.iconCustom = iconCustom
        self.icon = icon
        self.notes = notes
        self.status = status
    }

    // MARK: - Hashable
    
    // Hash value for the machine based on its unique identifier
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    // MARK: - Equatable
    
    // Define equality between two machine models for comparison
    static func == (lhs: Machine, rhs: Machine) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.iconCustom == rhs.iconCustom &&
        lhs.icon == rhs.icon &&
        lhs.notes == rhs.notes &&
        lhs.status == rhs.status
    }
}

// MARK: - Copy Machine Extension

// Extension for cloning a machine
extension Machine {
    func copy() -> Machine {
        let machine = Machine(
            id: self.id,
            name: self.name,
            iconCustom: self.iconCustom,
            icon: self.icon,
            notes: self.notes,
            status: self.status
        )
        return machine
    }
}

// MARK: - Machine Status Enumerator

// Enumerator for machine status
enum MachineStatus: String, Codable {
    case stopped
    case running
}
