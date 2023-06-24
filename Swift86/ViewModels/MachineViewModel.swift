//
//  MachineViewModel.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machine Data

// Handles machines data and interactions
class MachineViewModel: ObservableObject {
    
    // MARK: - Properties

    // Machines list
    @Published var machines: [Machine] = []
    
    // Machine instance
    @Published var machine = Machine()

    // Add new machine
    @Published var isShowingAddMachine = false

    // Editing machine
    @Published var isShowingEditMachine = false

    // Configuring machine
    @Published var isConfiguringMachine: Bool = false
    
    // Default machine icon
    var defaultIcon: NSImage? = NSImage(systemSymbolName: "pc", accessibilityDescription: "")
    
    // Custom machine icon
    @Published var customIcon: NSImage?
    
    // Selected machine icon
    var selectedIcon: Image {
        if machine.iconCustom && customIcon != nil,
           // Custom icon
           let nsImage = customIcon {
            return Image(nsImage: nsImage)
        } else {
            // Default icon
            let nsImage = defaultIcon!
            return Image(nsImage: nsImage)
        }
    }
    
    // Running machine process IDs
    @Published var runningProcesses: [UUID: Process] = [:]
    
    // FileManager default instance
    private let fileManager = FileManager.default
    
    // MARK: - Initialization
    
    init() {
        // Initialize machines library loading
        loadMachines()
    }

    // MARK: - Methods
    
    // Get access to the emulator
    func getEmulator(_ block: @escaping (URL, URL, URL) -> Void) {
        // Get emulator location
        let settings = (UserDefaults.standard.object(forKey: SettingsKeys.settings.rawValue) as? [String: Any]) ?? DefaultSettings.shared.defaults

        guard let emulatorPath = settings[SettingsKeys.emulatorPath.rawValue] as? String,
              let machinesPath = settings[SettingsKeys.machinesPath.rawValue] as? String,
              let romsPath = settings[SettingsKeys.romsPath.rawValue] as? String else {
            print("Emulator not found")
            return
        }

        // Resolve into URLs
        let emulatorURL = URL(filePath: emulatorPath).appendingPathComponent(MachineKeys.binary.rawValue)
        let machinesURL = URL(filePath: machinesPath)
        let romsURL = URL(filePath: romsPath)

        // Execute the provided block
        block(emulatorURL, machinesURL, romsURL)
    }
    
    // Get access to the machines library
    func getMachineLibrary(_ block: (URL) -> Void) {
        // Get machines library location
        let settings = (UserDefaults.standard.object(forKey: SettingsKeys.settings.rawValue) as? [String: Any]) ?? DefaultSettings.shared.defaults

        guard let machinesPath = settings[SettingsKeys.machinesPath.rawValue] as? String else {
            print("Machines not found")
            return
        }
        
        // Resolve into an URL
        let url = URL(filePath: machinesPath)
        
        // Execute the provided block
        block(url)
    }
    
    // Create machine icon
    func createMachineIcon(_ url: URL) {
        // Path to save the machine icon
        let iconURL = url.appendingPathComponent(MachineKeys.icon.rawValue)
        
        // If user selected a custom icon
        if machine.iconCustom && machine.icon != nil {
            // Custom icon
            guard let nsImage = machine.icon else {
                print("Error retrieving PNG data.")
                return
            }
            
            do {
                // Save image if new icon
                let imageRepresentation = NSBitmapImageRep(data: nsImage.tiffRepresentation!)
                let iconData = imageRepresentation?.representation(using: .png, properties: [:])
                try iconData!.write(to: iconURL)
                customIcon = nil
                return
            } catch {
                print("Error saving custom icon to file: \(error.localizedDescription)")
                return
            }
        } else {
            // Default icon
            do {
                // Delete old image if no icon
                if fileManager.fileExists(atPath: iconURL.path) {
                    try fileManager.removeItem(at: iconURL)
                }
                
                // Restore default icon
                machine.iconCustom = false
                machine.icon = nil
                customIcon = nil
            } catch {
                print("Error deleting icon file: \(error.localizedDescription)")
            }
        }
    }
    
    // Browse for machine icon
    func iconPicker() {
        // Access machine library
        getMachineLibrary { url in
            // Properties
            let fileManager = FileManager.default
            let machineURL = url.appendingPathComponent(machine.name)
            
            // Only for custom icon
            if machine.iconCustom {
                // Create an instance of NSOpenPanel
                let openPanel = NSOpenPanel()
                openPanel.canChooseFiles = true
                openPanel.canChooseDirectories = false
                openPanel.allowsMultipleSelection = false
                openPanel.allowedContentTypes = [.image]
                
                // Set the default path for the NSOpenPanel
                if !machineURL.path.isEmpty {
                    // Open in current machine folder if editing machine
                    openPanel.directoryURL = machineURL
                } else {
                    // Open in default user home folder if new machine
                    openPanel.directoryURL = fileManager.homeDirectoryForCurrentUser
                }
                
                // Show the dialog and return changes
                if openPanel.runModal() == NSApplication.ModalResponse.OK,
                   let url = openPanel.url {
                    // Pass icon and thumbnail icon
                    machine.icon = NSImage(contentsOf: url)!
                    customIcon = machine.icon
                }
            }
        }
    }
    
    // Create machine plist file
    func createMachinePlist(machine: Machine, url: URL) {
        // Create machine dictionary
        let machineInfo: [String: Any] = [
            MachineKeys.uuid.rawValue: machine.id.uuidString,
            MachineKeys.name.rawValue: machine.name,
            MachineKeys.iconCustom.rawValue: machine.iconCustom,
            MachineKeys.notes.rawValue: machine.notes as Any
        ]
        
        // Save machine plist file
        let plistURL = url.appendingPathComponent(MachineKeys.plist.rawValue)
        guard NSDictionary(dictionary: [MachineKeys.info.rawValue: machineInfo]).write(to: plistURL, atomically: true) else {
            print("Error saving machine '\(machine.name)' information to plist.")
            return
        }
    }
    
    // Add new machine
    func addNewMachine() {
        // Access machine library
        getMachineLibrary { url in
            // Machine folder path
            let machineURL = url.appendingPathComponent(machine.name)
            
            do {
                // Create machine folder
                try fileManager.createDirectory(at: machineURL, withIntermediateDirectories: true, attributes: nil)
                
                // Create machine icon, if any
                createMachineIcon(machineURL)

                // Save machine information to plist
                createMachinePlist(machine: machine, url: machineURL)
                
                // Append new machine to the list
                machines.append(machine)
                
                print("Machine '\(machine.name)' added successfully")
                
                // Reset new machine instance
                machine = Machine()
            } catch {
                print("Error creating folder for machine '\(machine.name)': \(error.localizedDescription)")
                return
            }
        }
    }
    
    // Edit existing machine
    func editMachine() {
        // Access machine library
        getMachineLibrary { url in
            // Define old and new machine paths
            guard let oldMachine = (machines.first { $0.id == machine.id }) else { return }
            let oldMachineURL = url.appendingPathComponent(oldMachine.name)
            let newMachineURL = url.appendingPathComponent(machine.name)
            
            // Check if machine exists
            guard fileManager.fileExists(atPath: oldMachineURL.path) else {
                print("Machine '\(oldMachine.name)' not found in library")
                return
            }
            
            do {
                // Move the machine
                try fileManager.moveItem(at: oldMachineURL, to: newMachineURL)
                
                // Update machine icon, if any
                createMachineIcon(newMachineURL)

                // Update machine information to plist
                createMachinePlist(machine: machine, url: newMachineURL)
                
                // Apply changes to existing machine
                if let index = machines.firstIndex(where: { $0.id == machine.id }) {
                    machines[index] = machine
                    print("Machine '\(machine.name)' edited successfully")
                }
                
                // Reset editing machine variable
                machine = Machine()
            } catch let error {
                print("Error editing machine '\(machine.name)': \(error.localizedDescription)")
            }
        }
    }

    // Delete machine
    func deleteMachine(_ machine: Machine) {
        // Access machine library
        getMachineLibrary { url in
            // Access machine folder
            let machineURL = url.appendingPathComponent(machine.name)
            
            do {
                // Delete the machine
                try fileManager.removeItem(at: machineURL)
                machines.removeAll(where: { $0.id == machine.id })
                print("Machine deleted successfully")
            } catch let error {
                print("Error deleting machine: \(error.localizedDescription)")
            }
        }
    }
    
    // Clone machine
    func cloneMachine(_ machine: Machine) {
        // Access machine library
        getMachineLibrary { url in
            // Get existing machines
            let existingMachines = machines.filter { $0.name.hasPrefix(machine.name) }

            // Check for highest available machine clone
            let highestCopyNumber = existingMachines
                .compactMap { machineName -> Int? in
                    let components = machineName.name.components(separatedBy: " ")
                    if let lastComponent = components.last,
                       let copyNumber = Int(lastComponent),
                       components.count > 2 {
                        return copyNumber
                    }
                    return nil
                }
                .max() ?? 0

            // Append new machine name
            let cloneNumber = highestCopyNumber + 1
            let baseName = machine.name.components(separatedBy: " copy").first ?? machine.name
            let cloneName = "\(baseName) copy \(cloneNumber)"
            
            // Create the clone machine
            let clone = Machine(name: cloneName, iconCustom: machine.iconCustom, notes: machine.notes)
            
            do {
                // Clone the machine contents
                let machineURL = url.appendingPathComponent(machine.name)
                let cloneURL = url.appendingPathComponent(clone.name)
                try fileManager.copyItem(at: machineURL, to: cloneURL)

                // Save clone information to plist
                createMachinePlist(machine: clone, url: cloneURL)
                
                // Append clone machine to the list
                machines.append(clone)
                loadMachines()
                print("Machine '\(machine.name)' cloned successfully")
            } catch let error {
                print("Error cloning machine '\(machine.name)': \(error.localizedDescription)")
            }
        }
    }
    
    // Move machine in list
    func moveMachine(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        // Move machine around in sidebar list
        machines.move(fromOffsets: indices, toOffset: newOffset)
        
        // Save the array of machine IDs to UserDefaults
        let machinesSort = machines.map { $0.id.uuidString }
        UserDefaults.standard.set(machinesSort, forKey: MachineKeys.list.rawValue)
        print("Machine list updated successfully")
    }
    
    // Load machines list
    func loadMachines() {
        // Access machine library
        getMachineLibrary { url in
            // Instance for machines library
            var loadedMachines = [Machine]()
            
            guard let machineLibrary = try? fileManager.contentsOfDirectory(atPath: url.path) else {
                print("No machines found.")
                return
            }
            
            // List the machines
            for machineFolder in machineLibrary {
                // Paths to machine folder, info and icon
                let machineURL = url.appendingPathComponent(machineFolder)
                let machineInfo = machineURL.appendingPathComponent(MachineKeys.plist.rawValue)
                let machineIcon = machineURL.appendingPathComponent(MachineKeys.icon.rawValue)
                
                // Check if machine exists
                if fileManager.fileExists(atPath: machineInfo.path) {
                    // Read machine properties from file
                    guard let properties = NSDictionary(contentsOf: machineInfo) as? [String: Any],
                          let info = properties[MachineKeys.info.rawValue] as? [String: Any] else {
                        print("Failed to read machine '\(machineFolder)' properties from file.")
                        continue
                    }
                    
                    // Create the loaded machines list
                    if let idString = info[MachineKeys.uuid.rawValue] as? String,
                       let id = UUID(uuidString: idString) {
                        let machine = Machine(
                            id: id,
                            name: info[MachineKeys.name.rawValue] as? String ?? "",
                            iconCustom: info[MachineKeys.iconCustom.rawValue] as? Bool ?? false,
                            notes: info[MachineKeys.notes.rawValue] as? String ?? ""
                        )
                        
                        // Get the machine icon
                        if machine.iconCustom && fileManager.fileExists(atPath: machineIcon.path) {
                            // Custom icon
                            let nsImage = machineIcon
                            machine.icon = NSImage(contentsOf: nsImage)
                        }
                        
                        // Append machine instance
                        loadedMachines.append(machine)
                    }
                }
            }
            
            // Sort the loadedMachines array based on the order of UUIDs
            loadedMachines.sort { machine1, machine2 in
                let uuidsInOrder = UserDefaults.standard.object(forKey: MachineKeys.list.rawValue) as? [String] ?? []
                return (uuidsInOrder.firstIndex(of: machine1.id.uuidString) ?? -1) < (uuidsInOrder.firstIndex(of: machine2.id.uuidString) ?? -1)
            }
            
            // Return machines sorted
            machines = loadedMachines
        }
    }
    
    // Run machine
    func runMachine(_ machine: Machine) {
        // Get emulator and library
        getEmulator { emulatorURL, machinesURL, romsURL in
            // Prepare process to run machine
            let process = Process()
            process.executableURL = emulatorURL
            process.arguments = [
                "-R", romsURL.path,
                "-V", machine.name,
                "-P", machinesURL.appendingPathComponent(machine.name).path
            ]
            
            do {
                // Run machine
                try process.run()
                                
                // Update the machine status to running
                DispatchQueue.main.async {
                    // Add the running process to the dictionary
                    self.runningProcesses[machine.id] = process

                    if let index = self.machines.firstIndex(where: { $0.id == machine.id }) {
                        self.machines[index].status = .running
                    }
                }
                
                // Monitor process termination
                process.terminationHandler = { [weak self] process in
                    DispatchQueue.main.async {
                        // Remove the process from the runningProcesses dictionary
                        self?.runningProcesses.removeValue(forKey: machine.id)
                        
                        if let index = self?.machines.firstIndex(where: { $0.id == machine.id }) {
                            self?.machines[index].status = .stopped
                        }
                    }
                }
            } catch {
                print("An error occurred: \(error.localizedDescription)")
            }
        }
    }
    
    // Configure machine
    func configureMachine(_ machine: Machine) {
        // Get emulator and library
        getEmulator { emulatorURL, machinesURL, romsURL in
            // Prepare process to configure machine
            let process = Process()
            process.executableURL = emulatorURL
            process.arguments = [
                "-R", romsURL.path,
                "-V", machine.name,
                "-P", machinesURL.appendingPathComponent(machine.name).path,
                "-S"
            ]

            do {
                // Configure machine
                try process.run()

                // Update the machine status to running and toggle configuration flag
                DispatchQueue.main.async {
                    // Add the running process to the dictionary
                    self.runningProcesses[machine.id] = process
                    self.isConfiguringMachine = true
                }

                // Monitor process termination
                process.terminationHandler = { [weak self] process in
                    DispatchQueue.main.async {
                        // Remove the process from the runningProcesses dictionary
                        self?.runningProcesses.removeValue(forKey: machine.id)
                        self?.isConfiguringMachine = false
                    }
                }
            } catch {
                print("An error occurred: \(error.localizedDescription)")
            }
        }
    }
    
    // Show machine in finder
    func showInFinder(_ machine: Machine) {
        // Access machine library
        getMachineLibrary { url in
            // Show machine
            NSWorkspace.shared.selectFile(url.appendingPathComponent(machine.name).path, inFileViewerRootedAtPath: "")
        }
    }
}

// MARK: - Enum Settings

// Enumerate machine keys
enum MachineKeys: String {
    case list = "MachinesList"
    case info = "Information"
    case uuid = "Id"
    case name = "Name"
    case iconCustom = "IconCustom"
    case icon = "Icon.png"
    case notes = "Notes"
    case plist = "86box.plist"
    case binary = "/Contents/MacOS/86Box"
}
