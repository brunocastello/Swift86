//
//  Library.swift
//  Swift86
//
//  Created by Bruno Castelló on 03/07/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machines Library Model

// Machines library model
@MainActor class Library: ObservableObject, Identifiable {
    
    // MARK: - Properties
    
    // Machines library instance
    @Published var machines: [Machine] = []
    
    // MARK: - Paths
    
    // Emulator location
    var emulatorURL: URL {
        // Selected or default emulator location
        let path = SettingsStore.shared.config.emulatorPath
        
        // Extract app name for binary execution
        let appURL = URL(filePath: path)
        let appName = appURL.deletingPathExtension().lastPathComponent
        
        // Return the unwrapped URL
        return URL(filePath: path).appendingPathComponent("/Contents/MacOS/\(appName)")
    }
    
    // Machines library location
    var machinesURL: URL {
        // Selected or default library location
        let path = SettingsStore.shared.config.machinesPath
        
        // Return the unwrapped URL
        return URL(filePath: path)
    }
    
    // ROMs library location
    var romsURL: URL {
        // Selected or default ROMs location
        let path = SettingsStore.shared.config.romsPath
        
        // Return the unwrapped URL
        return URL(filePath: path)
    }
    
    // MARK: - Initialization
    
    init() {
        // First run actions
        firstRun()
        
        // Load machines
        load()
    }
    
    // MARK: - First Run App Actions
    
    // First run actions
    func firstRun() {
        // Leave an unreadable settings file alone, it would be overwritten with defaults
        guard SettingsStore.shared.loadError == nil else { return }
        
        // Check if it's the first launch
        if !SettingsStore.shared.config.hasCompletedFirstRun {
            // Set the flag indicating that the app has launched before (deferred, we may be inside a view update)
            DispatchQueue.main.async {
                SettingsStore.shared.config.hasCompletedFirstRun = true
            }
            
            // Perform any first launch setup or logic here
            alertTitle = NSLocalizedString("Welcome", comment: "")
            alertMessage = NSLocalizedString("Please configure the application in Settings", comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
        }
    }
    
    // MARK: - Load Machines
    
    // Machines folder of the last successful load
    private var loadedMachinesURL: URL?
    
    // Load machines
    func load() {
        // Machines library
        var machines = [Machine]()
        
        // Identities only carry over while the machines folder is the same one
        let sameFolder = loadedMachinesURL?.standardizedFileURL == machinesURL.standardizedFileURL
        
        // List the machine folders
        guard let folders = MachineMetadata.candidateFolders(in: machinesURL) else { return }
        
        for machineURL in folders {
            // Bring notes over from a legacy plist, if any
            LegacyImport.importMachineIfNeeded(at: machineURL)
            
            // Only folders with an 86Box config or a Swift86 sidecar are machines
            guard MachineMetadata.isMachineFolder(machineURL) else { continue }
            
            // Machine name, notes and icon come from the folder
            let name = machineURL.lastPathComponent
            let machineIcon = machineURL.appendingPathComponent("Icon.png")
            let hasIcon = FileManager.default.fileExists(atPath: machineIcon.path)
            
            // Keep the identity and status of a machine that is already loaded
            let existing = sameFolder ? self.machines.first { $0.name == name } : nil
            
            // Create the loaded machines list
            var machine = Machine(
                id: existing?.id ?? UUID(),
                name: name,
                iconCustom: hasIcon,
                icon: hasIcon ? machineIcon.path : "",
                notes: MachineMetadata.load(from: machineURL)?.notes ?? ""
            )
            machine.status = existing?.status ?? .stopped
            
            // Append machine instance
            machines.append(machine)
        }
        
        // Take the sidebar order over from an old install, once (never over an unreadable settings file)
        var order = SettingsStore.shared.config.machineOrder
        if order.isEmpty && SettingsStore.shared.loadError == nil {
            let legacyOrder = LegacyImport.legacyMachineOrder(machinesURL: machinesURL)
            if !legacyOrder.isEmpty {
                order = legacyOrder
                
                // Store it (deferred, we may be inside a view update)
                DispatchQueue.main.async {
                    let store = SettingsStore.shared
                    if store.config.machineOrder.isEmpty && store.loadError == nil {
                        store.config.machineOrder = legacyOrder
                    }
                }
            }
        }
        
        // Sort the machines: custom order first, then the rest alphabetically
        var orderIndex = [String: Int]()
        for (index, name) in order.enumerated() where orderIndex[name] == nil {
            orderIndex[name] = index
        }
        machines.sort { first, last in
            switch (orderIndex[first.name], orderIndex[last.name]) {
            case let (a?, b?): return a < b
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return first.name.localizedStandardCompare(last.name) == .orderedAscending
            }
        }
        
        // Return machines
        self.machines = machines
        loadedMachinesURL = machinesURL
    }
    
    // MARK: - New Machine
    
    // New machine
    @Published var newMachine: Machine?
    
    // Create new machine
    func create(machine: Machine) {
        // Set machine folder path
        let machineURL = machinesURL.appendingPathComponent(machine.name)
        
        // Check for an existing machine with same name
        for existingMachine in machines {
            if existingMachine.name == machine.name {
                // Error saving machine
                alertTitle = String(format: NSLocalizedString("Error saving machine \"%@\"", comment: ""), machine.name)
                alertMessage = NSLocalizedString("A machine with this name already exists.", comment: "")
                alertOK = { }
                showCancel = false
                showAlert = true
                return
            }
        }

        do {
            // Create machine folder
            try FileManager.default.createDirectory(at: machineURL, withIntermediateDirectories: true, attributes: nil)

            // Save machine
            save(machine: machine, url: machineURL)
            
            // Keep the new machine at the end of the sidebar order
            if machines.contains(where: { $0.name == machine.name }) {
                SettingsStore.shared.config.machineOrder = machines.map(\.name)
            }
        } catch let error {
            // Error saving machine
            alertTitle = String(format: NSLocalizedString("Error saving machine \"%@\"", comment: ""), machine.name)
            alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
            return
        }
    }
    
    // MARK: - Edit Machine
    
    // Edited machine
    @Published var editMachine: Machine?
    
    // Edit machine
    func edit(machine: Machine) {
        // Find old and new machine paths
        guard let oldMachine = (machines.first { $0.id == machine.id }) else { return }
        let oldMachineURL = machinesURL.appendingPathComponent(oldMachine.name)
        let machineURL = machinesURL.appendingPathComponent(machine.name)
        
        // First check if machine exists
        guard FileManager.default.fileExists(atPath: oldMachineURL.path) else {
            // Error saving machine
            alertTitle = NSLocalizedString("Error", comment: "")
            alertMessage = String(format: NSLocalizedString("Could not find machine \"%@\"", comment: ""), machine.name)
            alertOK = { }
            showCancel = false
            showAlert = true
            return
        }
        
        do {
            // Move the machine if the name changed
            if oldMachine.name != machine.name {
                try FileManager.default.copyItem(at: oldMachineURL, to: machineURL)
            }

            // Update existing machine
            save(machine: machine, url: machineURL)
            
            // Move the machine if the name changed
            if oldMachine.name != machine.name {
                try FileManager.default.removeItem(at: oldMachineURL)
                
                // Keep the machine's place in the sidebar order
                if let index = SettingsStore.shared.config.machineOrder.firstIndex(of: oldMachine.name) {
                    SettingsStore.shared.config.machineOrder[index] = machine.name
                }
            }
        } catch let error {
            // Error editing machine
            alertTitle = String(format: NSLocalizedString("Error saving machine \"%@\"", comment: ""), machine.name)
            alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
        }
    }
    
    // MARK: - Save Machine
    
    // Save machine
    func save(machine: Machine, url: URL) {
        // No longer a constant
        var machine = machine
        
        // Stop saving machine due to an error
        // (Avoids losing entire library!)
        if machine.name.isEmpty {
            alertTitle = NSLocalizedString("Error", comment: "")
            alertMessage = NSLocalizedString("This machine must have a name.", comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
            return
        }
        
        // Set paths for icons
        let icon = url.appendingPathComponent("Icon.png")
        let newIcon = URL(filePath: machine.icon)
        
        // Check if an icon was selected or not
        if machine.iconCustom && machine.icon.isEmpty {
            machine.iconCustom = false
        } else if machine.iconCustom && !machine.icon.isEmpty {
            machine.icon = "Icon.png"
        } else {
            machine.icon = ""
        }
        
        // If user selected a custom icon
        if machine.iconCustom && !machine.icon.isEmpty {
            // Custom icon
            do {
                // Delete old image
                if FileManager.default.fileExists(atPath: icon.path) && newIcon.path != icon.path {
                    try FileManager.default.removeItem(atPath: icon.path)
                    machine.icon = ""
                }
                
                // Save image if new icon
                if newIcon.path != icon.path {
                    try FileManager.default.copyItem(at: newIcon, to: icon)
                }
                machine.icon = icon.path
            } catch {
                alertTitle = String(format: NSLocalizedString("Error saving icon for machine \"%@\"", comment: ""), machine.name)
                alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
                alertOK = { }
                showCancel = false
                showAlert = true
                return
            }
        } else {
            // Default icon
            do {
                // Delete old image if no icon
                if FileManager.default.fileExists(atPath: icon.path) {
                    try FileManager.default.removeItem(atPath: icon.path)
                    machine.icon = ""
                }
            } catch {
                alertTitle = String(format: NSLocalizedString("Error deleting icon for machine \"%@\"", comment: ""), machine.name)
                alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
                alertOK = { }
                showCancel = false
                showAlert = true
                return
            }
        }
        
        // Save machine sidecar
        do {
            try MachineMetadata(notes: machine.notes).save(to: url)
        } catch {
            alertTitle = NSLocalizedString("Error", comment: "")
            alertMessage = String(format: NSLocalizedString("Could not save machine \"%@\"", comment: ""), machine.name)
            alertOK = { }
            showCancel = false
            showAlert = true
            return
        }
        
        // Save machine into library
        if let index = machines.firstIndex(where: { $0.id == machine.id }) {
            // Update existing machine
            machines[index] = machine
        } else {
            // Save new machine
            machines.append(machine)
        }
    }
    
    // MARK: - Move Machine
    
    // Move machine
    func move(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        // Move machine around in sidebar list
        machines.move(fromOffsets: indices, toOffset: newOffset)
        
        // Save the folder names as the sidebar order
        SettingsStore.shared.config.machineOrder = machines.map(\.name)
    }
    
    // MARK: - Clone machine
    
    // Clone machine
    func clone(machine: Machine) {
        // Set base for clone machine name
        let baseTitle = machine.name.replacingOccurrences(of: #"\scopy\s\d+$"#, with: "", options: .regularExpression)
        
        // Count for existing clones
        let copyCount = machines.filter { $0.name.hasPrefix(baseTitle) }.count
        
        // Set clone machine name
        let cloneTitle = copyCount > 0 ? "\(baseTitle) copy \(copyCount)" : baseTitle
        
        // Create the clone machine
        let cloneMachine = Machine(
            id: UUID(),
            name: cloneTitle,
            iconCustom: machine.iconCustom,
            icon: machine.icon,
            notes: machine.notes
        )
        
        do {
            // Clone the machine contents
            let machineURL = machinesURL.appendingPathComponent(machine.name)
            let cloneMachineURL = machinesURL.appendingPathComponent(cloneMachine.name)
            try FileManager.default.copyItem(at: machineURL, to: cloneMachineURL)

            // Save clone information
            save(machine: cloneMachine, url: cloneMachineURL)
            
            // Keep the clone at the end of the sidebar order
            if machines.contains(where: { $0.name == cloneMachine.name }) {
                SettingsStore.shared.config.machineOrder = machines.map(\.name)
            }
        } catch let error {
            // Error cloning machine
            alertTitle = String(format: NSLocalizedString("Error cloning machine \"%@\"", comment: ""), machine.name)
            alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
        }
    }
    
    // MARK: - Run Machine
    
    // Running machine process IDs
    @Published var runningProcesses: [UUID: Process] = [:]
    
    // Run machine
    func runMachine(machine: Machine) {
        // Prepare process to run machine
        let process = Process()
        process.executableURL = emulatorURL
        process.arguments = [
            "-R", romsURL.path,
            "-V", machine.name,
            "-P", machinesURL.appendingPathComponent(machine.name).path
        ]
        
        do {
            // Start process
            try process.run()
                            
            DispatchQueue.main.async {
                // Add the running process to the queue
                self.runningProcesses[machine.id] = process

                // Update machine status to running
                if let index = self.machines.firstIndex(where: { $0.id == machine.id }) {
                    self.machines[index].status = .running
                }
            }
            
            // Handle process termination
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    // Remove the process from the queue when terminated
                    self?.runningProcesses.removeValue(forKey: machine.id)
                    
                    // Update the machine status to stopped
                    if let index = self?.machines.firstIndex(where: { $0.id == machine.id }) {
                        self?.machines[index].status = .stopped
                    }
                }
            }
        } catch {
            // Error running machine
            self.alertTitle = NSLocalizedString("An error occurred", comment: "")
            self.alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            self.alertOK = { }
            self.showCancel = false
            self.showAlert = true
        }
    }
    
    // MARK: - Configure Machine
    
    // Configure machine
    func configureMachine(machine: Machine) {
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
            // Start process
            try process.run()

            DispatchQueue.main.async {
                // Add the running process to the queue
                self.runningProcesses[machine.id] = process
                
                // Update machine status to configuring
                if let index = self.machines.firstIndex(where: { $0.id == machine.id }) {
                    self.machines[index].status = .configuring
                }
            }

            // Handle process termination
            process.terminationHandler = { [weak self] process in
                DispatchQueue.main.async {
                    // Remove the process from the queue when terminated
                    self?.runningProcesses.removeValue(forKey: machine.id)
                    
                    // Update the machine status to stopped
                    if let index = self?.machines.firstIndex(where: { $0.id == machine.id }) {
                        self?.machines[index].status = .stopped
                    }
                }
            }
        } catch {
            // Error configuring machine
            self.alertTitle = NSLocalizedString("An error occurred", comment: "")
            self.alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            self.alertOK = { }
            self.showCancel = false
            self.showAlert = true
        }
    }
    
    // MARK: - Show Machine Size
    
    // Calculate and return machine size
    func sizeOf(machine: String) -> String? {
        // Declare size variable
        var size: String?

        // Set machine path
        let path = machinesURL.appendingPathComponent(machine).path
        
        // Total machine size
        var totalSize: UInt64 = 0
        
        // Enumerate machine folder contents
        if let enumerator = FileManager.default.enumerator(atPath: path) {
            while let subpath = enumerator.nextObject() as? String {
                let fullSubpath = path + "/" + subpath
                if let attributes = try? FileManager.default.attributesOfItem(atPath: fullSubpath),
                   let fileSize = attributes[.size] as? UInt64 {
                    totalSize += fileSize
                }
            }
        }
        
        // Get human readable folder size
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        byteCountFormatter.countStyle = .file
        size = byteCountFormatter.string(fromByteCount: Int64(totalSize))
        
        // Return size
        return size
    }
    
    // MARK: - Find Machine
    
    // Show machine in Finder
    func find(machine: Machine) {
        // Show machine
        NSWorkspace.shared.selectFile(machinesURL.appendingPathComponent(machine.name).path, inFileViewerRootedAtPath: "")
    }
    
    // MARK: - Delete Machine
    
    // Delete machine
    func delete(machine: Machine) {
        // Stop saving machine due to an error
        // (Avoids losing entire library)
        if machine.name.isEmpty {
            alertTitle = NSLocalizedString("Error", comment: "")
            alertMessage = NSLocalizedString("This machine must have a name.", comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
            return
        }
        
        // Confirm machine removal
        alertTitle = String(format: NSLocalizedString("Are you sure you want to delete \"%@\" permanently?", comment: ""), machine.name)
        alertMessage = NSLocalizedString("You cannot undo this action.", comment: "")
        alertOK = {
            // Access machine folder
            let machineURL = self.machinesURL.appendingPathComponent(machine.name)
            
            do {
                // Delete the machine
                try FileManager.default.removeItem(at: machineURL)
                self.machines.removeAll(where: { $0.id == machine.id })
                SettingsStore.shared.config.machineOrder.removeAll { $0 == machine.name }
            } catch let error {
                // Error deleting machine
                self.alertTitle = String(format: NSLocalizedString("Error deleting machine \"%@\"", comment: ""), machine.name)
                self.alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
                self.alertOK = { }
                self.showCancel = false
                self.showAlert = true
            }
        }
        showCancel = true
        showAlert = true
    }
    
    // MARK: - Machine Icon Picker
    
    // Browse for machine icon
    func iconPicker(machine: Machine, completion: @escaping (URL?) -> Void) {
        // Set path to save icon
        let machineURL = machinesURL.appendingPathComponent(machine.name)
        
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
                openPanel.directoryURL = FileManager.default.homeDirectoryForCurrentUser
            }
            
            // Show the dialog and return changes
            if openPanel.runModal() == NSApplication.ModalResponse.OK,
               let iconURL = openPanel.url {
                // return the icon URL
                completion(iconURL)
            }
        }
    }
    
    // MARK: - Alerts
    
    // Show alert
    @Published var showAlert = false
    
    // Alert title
    var alertTitle = ""
    
    // Alert message
    var alertMessage = ""
    
    // Alert action
    var alertOK: (() -> Void)?
    
    // Show dismiss or not
    var showCancel = false
}
