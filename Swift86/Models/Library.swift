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
class Library: ObservableObject, Identifiable {
    
    // MARK: - Properties
    
    // Machines library instance
    @Published var machines: [Machine] = []
    
    // MARK: - Paths
    
    // Emulator location
    var emulatorURL: URL {
        // Unwrap the selected or default library location
        let string = UserDefaults.standard.string(forKey: "EmulatorPath") ?? AppSettings.shared.emulatorPath
        let path = string
        
        // Return the unwrapped URL
        return URL(filePath: path).appendingPathComponent("/Contents/MacOS/86Box")
    }
    
    // Machines library location
    var machinesURL: URL {
        // Unwrap the selected or default library location
        let string = UserDefaults.standard.string(forKey: "MachinesPath") ?? AppSettings.shared.machinesPath
        let path = string
        
        // Return the unwrapped URL
        return URL(filePath: path)
    }
    
    // ROMs library location
    var romsURL: URL {
        // Unwrap the selected or default library location
        let string = UserDefaults.standard.string(forKey: "RomsPath") ?? AppSettings.shared.romsPath
        let path = string
        
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
    
    // Is it the first time running the app?
    var FirstRun: Bool = UserDefaults.standard.bool(forKey: "First Run")
    
    // First run actions
    func firstRun() {
        // Reset UserDefaults FOR DEBUGGING ONLY!
        // UserDefaults.standard.removePersistentDomain(forName: Bundle.main.bundleIdentifier!)
        
        // Check if it's the first launch
        if FirstRun != true {
            // Set the flag indicating that the app has launched before
            UserDefaults.standard.setValue(true, forKey: "First Run")
            
            // Perform any first launch setup or logic here
            alertTitle = NSLocalizedString("Welcome", comment: "")
            alertMessage = NSLocalizedString("Please configure the application in Settings", comment: "")
            alertOK = { }
            showCancel = false
            showAlert = true
        }
    }
    
    // MARK: - Load Machines
    
    // Load machines
    func load() {
        // Machines library
        var machines = [Machine]()
        
        // List the machines
        guard let directory = try? FileManager.default.contentsOfDirectory(atPath: machinesURL.path) else { return }
        
        for folder in directory {
            // Paths to machine folder, properties and icon
            let machineURL = machinesURL.appendingPathComponent(folder)
            let machineInfo = machineURL.appendingPathComponent("86box.plist")
            let machineIcon = machineURL.appendingPathComponent("Icon.png")
            
            // Check if machine exists
            if FileManager.default.fileExists(atPath: machineInfo.path) {
                // Read machine properties from file
                guard let properties = NSDictionary(contentsOf: machineInfo) as? [String: Any],
                      var info = properties["Information"] as? [String: Any] else {
                    continue
                }
                
                // Get the machine icon
                if info["IconCustom"] as? Bool ?? false && FileManager.default.fileExists(atPath: machineIcon.path) {
                    // Custom icon
                    info["Icon"] = machineIcon.path
                }
                
                // Create the loaded machines list
                let machine = Machine(
                    id: UUID(uuidString: info["Id"] as! String)!,
                    name: info["Name"] as? String ?? "",
                    iconCustom: info["IconCustom"] as? Bool ?? false,
                    icon: info["Icon"] as? String ?? "",
                    notes: info["Notes"] as? String ?? ""
                )
                
                // Append machine instance
                machines.append(machine)
            }
        }
        
        // Sort the machines based on custom order
        machines.sort { first, last in
            let order = UserDefaults.standard.object(forKey: "MachinesList") as? [String] ?? []
            return (order.firstIndex(of: first.id.uuidString) ?? -1) < (order.firstIndex(of: last.id.uuidString) ?? -1)
        }
        
        // Return machines
        self.machines = machines
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
        
        // Set paths for icons and property list file
        let icon = url.appendingPathComponent("Icon.png")
        let newIcon = URL(filePath: machine.icon)
        let plist = url.appendingPathComponent("86box.plist")
        
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
        
        // Create machine property list
        let machineInfo: [String: Any] = [
            "Id": machine.id.uuidString,
            "Name": machine.name,
            "IconCustom": machine.iconCustom,
            "Icon": machine.icon,
            "Notes": machine.notes
        ]

        // Save machine property list
        guard NSDictionary(dictionary: ["Information": machineInfo]).write(to: plist, atomically: true) else {
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
        
        // Save the array of machine IDs to UserDefaults
        let machinesSort = machines.map { $0.id.uuidString }
        UserDefaults.standard.set(machinesSort, forKey: "MachinesList")
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

            // Save clone information to plist
            save(machine: cloneMachine, url: cloneMachineURL)
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
