//
//  Store.swift
//  Swift86
//
//  Created by Bruno Castelló on 03/07/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: Machines Library Operations

class Store: ObservableObject {
    
    // MARK: - Machines library properties
    
    // Machines list
    @Published var machines: [Machine] = []
    
    // Add new machine
    @Published var isShowingAddMachine = false
    
    // Edit machine
    @Published var editMachine: Machine?
    @Published var isShowingEditMachine = false
        
    // Configuring machine
    @Published var isConfiguringMachine: Bool = false
    
    // MARK: - Running processes
    
    // Running machine process IDs
    @Published var runningProcesses: [UUID: Process] = [:]
    
    // MARK: - Reusable Alert
    
    // Show alert
    @Published var showAlert = false
    
    // Alert title
    var alertTitle = ""
    
    // Alert message
    var alertMessage = ""
    
    // Alert action
    var okAction: (() -> Void)?
    
    // Show dismiss or not
    var showCancelButton = false
    
    // MARK: - First App Run Actions
    var FirstRun: Bool = UserDefaults.standard.bool(forKey: "First Run")

    // MARK: - Initialization
    
    init() {
        // First run actions
        firstRun()
        
        // Initialize machines library loading
        loadMachines()
    }
    
    // MARK: - Methods
    
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
            alertMessage = NSLocalizedString("Please go to settings to set up first", comment: "")
            okAction = { }
            showCancelButton = false
            showAlert = true
        }
    }
    
    // Get access to the emulator
    func getEmulator(_ block: @escaping (URL, URL, URL) -> Void) {
        // Get emulator location
        guard let emulatorPath = UserDefaults.standard.string(forKey: "EmulatorPath"),
              let machinesPath = UserDefaults.standard.string(forKey: "MachinesPath"),
              let romsPath = UserDefaults.standard.string(forKey: "RomsPath") else {
            return
        }
        
        // Resolve into URLs
        let emulatorURL = URL(filePath: emulatorPath).appendingPathComponent("/Contents/MacOS/86Box")
        let machinesURL = URL(filePath: machinesPath)
        let romsURL = URL(filePath: romsPath)
        
        // Show alert if there is no emulator found
        if !FileManager.default.fileExists(atPath: emulatorURL.path) {
            alertTitle = NSLocalizedString("Emulator not found", comment: "")
            alertMessage = NSLocalizedString("Please go to settings and set the correct path", comment: "")
            okAction = { }
            showCancelButton = false
            showAlert = true
        // Show alert if there are no ROMs found
        } else if !FileManager.default.fileExists(atPath: romsURL.path) {
            alertTitle = NSLocalizedString("ROMs not found", comment: "")
            alertMessage = NSLocalizedString("Please go to settings and set the correct path", comment: "")
            okAction = { }
            showCancelButton = false
            showAlert = true
        }

        // Execute the provided block
        block(emulatorURL, machinesURL, romsURL)
    }
    
    // Get access to the machines library
    private func getMachineLibrary(_ block: (URL) -> Void) {
        // Get machines library location
        guard let machinesPath = UserDefaults.standard.string(forKey: "MachinesPath") else {
            return
        }
        
        // Resolve into an URL
        let machinesURL = URL(filePath: machinesPath)
        
        // Execute the provided block
        block(machinesURL)
    }
    
    // Browse for machine icon
    func showIconPicker(machine: Machine, completion: @escaping (URL?) -> Void) {
        // Access machine library
        getMachineLibrary { machinesURL in
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
    }
    
    // Create machine icon
    func createMachineIcon(machine: Machine, url: URL) {
        // Path to save the machine icon
        let iconURL = url.appendingPathComponent("Icon.png")
        
        // If user selected a custom icon
        if machine.iconCustom && machine.icon != nil {
            // Custom icon
            guard let nsImage = machine.icon else {
                alertTitle = NSLocalizedString("Error retrieving PNG Data", comment: "")
                alertMessage = NSLocalizedString("Unable to generate the machine icon", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
                return
            }
            
            do {
                // Save image if new icon
                let imageRepresentation = NSBitmapImageRep(data: nsImage.tiffRepresentation!)
                let iconData = imageRepresentation?.representation(using: .png, properties: [:])
                try iconData!.write(to: iconURL)
                return
            } catch {
                alertTitle = NSLocalizedString("Error saving custom icon to file", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
                return
            }
        } else {
            // Default icon
            do {
                // Delete old image if no icon
                if FileManager.default.fileExists(atPath: iconURL.path) {
                    try FileManager.default.removeItem(at: iconURL)
                }
            } catch {
                alertTitle = NSLocalizedString("Error deleting icon file", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
            }
        }
    }
    
    // Create machine plist file
    func createMachinePlist(machine: Machine, url: URL) {
        // Create machine dictionary
        let machineInfo: [String: Any] = [
            "Id": machine.id.uuidString,
            "Name": machine.name,
            "IconCustom": machine.icon != nil ? true : false,
            "Notes": machine.notes as Any
        ]
        
        // Save machine plist file
        let plistURL = url.appendingPathComponent("86box.plist")
        guard NSDictionary(dictionary: ["Information": machineInfo]).write(to: plistURL, atomically: true) else {
            alertTitle = NSLocalizedString("Error saving machine", comment: "")
            alertMessage = NSLocalizedString("Could not save the '\(machine.name)' machine information", comment: "")
            okAction = { }
            showCancelButton = false
            showAlert = true
            return
        }
    }
    
    // Calculate and return machine size in byte format
    func machineSize(machine: String) -> String? {
        // Declare size variable
        var size: String?
        
        // Access machine library
        getMachineLibrary { machinesURL in
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
        }
        
        // Return size
        return size
    }
    
    // Load machines library
    func loadMachines() {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Instance for machines library
            var loadedMachines = [Machine]()
            
            guard let machinesLibrary = try? FileManager.default.contentsOfDirectory(atPath: machinesURL.path) else {
                alertTitle = NSLocalizedString("No machines found", comment: "")
                alertMessage = NSLocalizedString("No machines were found in this library", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
                return
            }
            
            // List the machines
            for machineFolder in machinesLibrary {
                // Paths to machine folder, info and icon
                let machineURL = machinesURL.appendingPathComponent(machineFolder)
                let machineInfo = machineURL.appendingPathComponent("86box.plist")
                let machineIcon = machineURL.appendingPathComponent("Icon.png")
                
                // Check if machine exists
                if FileManager.default.fileExists(atPath: machineInfo.path) {
                    // Read machine properties from file
                    guard let properties = NSDictionary(contentsOf: machineInfo) as? [String: Any],
                          var info = properties["Information"] as? [String: Any] else {
                        alertTitle = NSLocalizedString("No machine found", comment: "")
                        alertMessage = NSLocalizedString("Failed to read machine '\(machineFolder)' properties from file", comment: "")
                        okAction = { }
                        showCancelButton = false
                        showAlert = true
                        continue
                    }
                    
                    // Get the machine icon
                    if info["IconCustom"] as? Bool ?? false && FileManager.default.fileExists(atPath: machineIcon.path) {
                        // Custom icon
                        let nsImage = machineIcon
                        info["Icon"] = NSImage(contentsOf: nsImage)
                    }
                    
                    // Create the loaded machines list
                    let machine = Machine(
                        id: UUID(uuidString: info["Id"] as! String)!,
                        name: info["Name"] as? String ?? "",
                        iconCustom: info["IconCustom"] as? Bool ?? false,
                        icon: info["Icon"] as? NSImage,
                        notes: info["Notes"] as? String ?? ""
                    )
                                        
                    // Append machine instance
                    loadedMachines.append(machine)
                }
            }
            
            // Sort the loadedMachines array based on the order of UUIDs
            loadedMachines.sort { first, last in
                let order = UserDefaults.standard.object(forKey: "MachinesList") as? [String] ?? []
                return (order.firstIndex(of: first.id.uuidString) ?? -1) < (order.firstIndex(of: last.id.uuidString) ?? -1)
            }
            
            // Return machines sorted
            machines = loadedMachines
        }
    }
    
    // Add new machine
    func addMachine(machine: Machine) {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Set machine folder path
            let machineURL = machinesURL.appendingPathComponent(machine.name)

            do {
                // Create machine folder
                try FileManager.default.createDirectory(at: machineURL, withIntermediateDirectories: true, attributes: nil)
                
                // Generate machine icon
                createMachineIcon(machine: machine, url: machineURL)
            
                // Generate property list and save
                createMachinePlist(machine: machine, url: machineURL)
            
                // Save machine
                machines.append(machine)

                // Reload library
                loadMachines()
            } catch {
                // Error saving machine
                alertTitle = NSLocalizedString("Error saving machine '\(machine.name)'", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
                return
            }
        }
    }
    
    // Edit machine
    func editMachine(machine: Machine) {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Define old and new machine paths
            guard let oldMachine = (machines.first { $0.id == machine.id }) else { return }
            let oldMachineURL = machinesURL.appendingPathComponent(oldMachine.name)
            let newMachineURL = machinesURL.appendingPathComponent(machine.name)
            
            // Check if machine exists
            guard FileManager.default.fileExists(atPath: oldMachineURL.path) else {
                alertTitle = NSLocalizedString("Could not find machine '\(oldMachine.name)'", comment: "")
                alertMessage = NSLocalizedString("Machine '\(oldMachine.name)' not found in library", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
                return
            }
            
            do {
                // Move the machine
                try FileManager.default.moveItem(at: oldMachineURL, to: newMachineURL)
                
                // Generate machine icon
                createMachineIcon(machine: machine, url: newMachineURL)
                
                // Update machine information to plist
                createMachinePlist(machine: machine, url: newMachineURL)
                
                // Save changes to new machine
                if let index = machines.firstIndex(where: { $0.id == machine.id }) {
                    // Replace edited machine
                    machines[index] = machine

                    // Reload library
                    loadMachines()
                }
            } catch let error {
                // Error editing machine
                alertTitle = NSLocalizedString("Error saving machine '\(machine.name)'", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
            }
        }
    }
    
    // Delete machine
    func deleteMachine(machine: Machine) {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Access machine folder
            let machineURL = machinesURL.appendingPathComponent(machine.name)
            
            do {
                // Delete the machine
                try FileManager.default.removeItem(at: machineURL)
                machines.removeAll(where: { $0.id == machine.id })
            } catch let error {
                // Error deleting machine
                alertTitle = NSLocalizedString("Error deleting machine '\(machine.name)'", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
            }
        }
    }
    
    // Clone machine
    func cloneMachine(machine: Machine) {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Set base machine name
            let baseTitle = machine.name.replacingOccurrences(of: #"\scopy\s\d+$"#, with: "", options: .regularExpression)
            
            // Count for existing clones
            let copyCount = machines.filter { $0.name.hasPrefix(baseTitle) }.count
            
            // Set clone machine name
            let newTitle = copyCount > 0 ? "\(baseTitle) copy \(copyCount)" : baseTitle
            
            // Create the clone machine
            let newMachine = Machine(
                id: UUID(),
                name: newTitle,
                iconCustom: machine.iconCustom,
                icon: machine.icon,
                notes: machine.notes
            )
            
            do {
                // Clone the machine contents
                let machineURL = machinesURL.appendingPathComponent(machine.name)
                let newMachineURL = machinesURL.appendingPathComponent(newMachine.name)
                try FileManager.default.copyItem(at: machineURL, to: newMachineURL)

                // Save clone information to plist
                createMachinePlist(machine: newMachine, url: newMachineURL)

                // Append the cloned machine to list
                machines.append(newMachine)
            } catch let error {
                // Error cloning machine
                alertTitle = NSLocalizedString("Error cloning machine '\(machine.name)'", comment: "")
                alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                okAction = { }
                showCancelButton = false
                showAlert = true
            }
        }
    }
    
    // Move machine in list
    func moveMachine(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        // Move machine around in sidebar list
        machines.move(fromOffsets: indices, toOffset: newOffset)
        
        // Save the array of machine IDs to UserDefaults
        let machinesSort = machines.map { $0.id.uuidString }
        UserDefaults.standard.set(machinesSort, forKey: "MachinesList")
    }
    
    // Run machine
    func runMachine(machine: Machine) {
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
                                
                DispatchQueue.main.async {
                    // Add the running process to the queue
                    self.runningProcesses[machine.id] = process

                    // Update machine status to running
                    if let index = self.machines.firstIndex(where: { $0.id == machine.id }) {
                        self.machines[index].status = .running
                    }
                }
                
                // Monitor process termination
                process.terminationHandler = { [weak self] process in
                    DispatchQueue.main.async {
                        // Remove the process from the queue
                        self?.runningProcesses.removeValue(forKey: machine.id)
                        
                        // Update the machine status to stopped
                        if let index = self?.machines.firstIndex(where: { $0.id == machine.id }) {
                            self?.machines[index].status = .stopped
                        }
                    }
                }
            } catch {
                self.alertTitle = NSLocalizedString("An error occurred", comment: "")
                self.alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                self.okAction = { }
                self.showCancelButton = false
                self.showAlert = true
            }
        }
    }
    
    // Configure machine
    func configureMachine(machine: Machine) {
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

                DispatchQueue.main.async {
                    // Add the running process to the queue
                    self.runningProcesses[machine.id] = process
                    
                    // Toggle configuration flag
                    self.isConfiguringMachine = true
                }

                // Monitor process termination
                process.terminationHandler = { [weak self] process in
                    DispatchQueue.main.async {
                        // Remove the running process to the queue
                        self?.runningProcesses.removeValue(forKey: machine.id)
                        
                        // Toggle configuration flag again
                        self?.isConfiguringMachine = false
                    }
                }
            } catch {
                self.alertTitle = NSLocalizedString("An error occurred", comment: "")
                self.alertMessage = NSLocalizedString("\(error.localizedDescription)", comment: "")
                self.okAction = { }
                self.showCancelButton = false
                self.showAlert = true
            }
        }
    }
    
    // Show machine in finder
    func showInFinder(machine: Machine) {
        // Access machine library
        getMachineLibrary { machinesURL in
            // Show machine
            NSWorkspace.shared.selectFile(machinesURL.appendingPathComponent(machine.name).path, inFileViewerRootedAtPath: "")
        }
    }
}
