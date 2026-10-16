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
    
    init(loadsLibrary: Bool = true) {
        // Previews skip the real library
        guard loadsLibrary else { return }
        
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
    
    // MARK: - Machine Errors
    
    // Errors raised when creating or editing machines
    enum MachineError: LocalizedError {
        case invalidName(MachineNameError)
        case machineRunning
        case invalidIcon
        case notFound(String)
        case io(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidName(let error): return error.message
            case .machineRunning: return "Stop the machine before renaming it."
            case .invalidIcon: return "The selected file is not a valid image."
            case .notFound(let name): return String(format: NSLocalizedString("Could not find machine \"%@\"", comment: ""), name)
            case .io(let error): return error.localizedDescription
            }
        }
    }
    
    // MARK: - New Machine
    
    // New machine
    @Published var newMachine: Machine?
    
    // Create new machine
    @discardableResult
    func create(_ draft: Machine) throws -> Machine {
        // Validate the name
        let name: String
        switch MachineFiles.validateName(draft.name, in: machinesURL) {
        case .success(let valid): name = valid
        case .failure(let error): throw MachineError.invalidName(error)
        }
        
        // Decode the icon before touching the file system
        let folderURL = machinesURL.appendingPathComponent(name)
        let iconPlan = try prepareIcon(draft, ownIcons: [folderURL])
        
        // Create the machine folder (never a 86box.cfg, 86Box makes its own)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        } catch {
            throw MachineError.io(error)
        }
        
        do {
            // Write the sidecar and the icon
            try MachineMetadata(notes: draft.notes).save(to: folderURL)
            try commitIcon(iconPlan, in: folderURL)
            var machine = draft
            machine.name = name
            machine.status = .stopped
            machine.icon = iconPath(in: folderURL)
            machine.iconCustom = !machine.icon.isEmpty
            
            // Keep the new machine at the end of the sidebar order
            machines.append(machine)
            SettingsStore.shared.config.machineOrder = machines.map(\.name)
            return machine
        } catch {
            // Remove only the folder just created
            try? FileManager.default.removeItem(at: folderURL)
            throw (error as? MachineError) ?? MachineError.io(error)
        }
    }
    
    // MARK: - Edit Machine
    
    // Edited machine
    @Published var editMachine: Machine?
    
    // Update an edited machine
    func update(_ edited: Machine) throws {
        // Find the machine being edited
        guard let index = machines.firstIndex(where: { $0.id == edited.id }) else {
            throw MachineError.notFound(edited.name)
        }
        let old = machines[index]
        let oldURL = machinesURL.appendingPathComponent(old.name)
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw MachineError.notFound(old.name)
        }
        
        // Validate the name
        let name: String
        switch MachineFiles.validateName(edited.name, in: machinesURL, renaming: old.name) {
        case .success(let valid): name = valid
        case .failure(let error): throw MachineError.invalidName(error)
        }
        let renamed = name != old.name
        if renamed && old.status != .stopped { throw MachineError.machineRunning }
        
        // Decode the icon before touching the file system
        let newURL = machinesURL.appendingPathComponent(name)
        var iconPlan = try prepareIcon(edited, ownIcons: [oldURL, newURL])
        if edited.iconCustom && edited.icon == old.icon { iconPlan = .keep }
        
        // Rename the folder if the name changed
        var folderURL = oldURL
        if renamed {
            do {
                try MachineFiles.renameFolder(from: oldURL, to: newURL)
            } catch {
                throw MachineError.io(error)
            }
            folderURL = newURL
            
            // Keep the machine's place in the sidebar order
            if let orderIndex = SettingsStore.shared.config.machineOrder.firstIndex(of: old.name) {
                SettingsStore.shared.config.machineOrder[orderIndex] = name
            }
            machines[index].name = name
        }
        
        // Write the sidecar and the icon in the (possibly new) folder
        do {
            try MachineMetadata(notes: edited.notes).save(to: folderURL)
            try commitIcon(iconPlan, in: folderURL)
            machines[index].notes = edited.notes
        } catch {
            // The rename stays, show the current state
            machines[index].icon = iconPath(in: folderURL)
            machines[index].iconCustom = !machines[index].icon.isEmpty
            throw (error as? MachineError) ?? MachineError.io(error)
        }
        machines[index].icon = iconPath(in: folderURL)
        machines[index].iconCustom = !machines[index].icon.isEmpty
    }
    
    // MARK: - Machine Icon
    
    // What to do with a machine's Icon.png
    private enum IconPlan {
        case keep
        case remove
        case write(Data)
    }
    
    // Path of the machine's Icon.png, or empty if it has none
    private func iconPath(in folder: URL) -> String {
        let icon = folder.appendingPathComponent("Icon.png")
        return FileManager.default.fileExists(atPath: icon.path) ? icon.path : ""
    }
    
    // Decide the icon change and decode the chosen image, without touching any machine file
    private func prepareIcon(_ machine: Machine, ownIcons folders: [URL]) throws -> IconPlan {
        // Default icon, no file
        if !machine.iconCustom || machine.icon.isEmpty { return .remove }
        
        // The machine's own icon needs no work
        let chosen = URL(filePath: machine.icon).standardizedFileURL.resolvingSymlinksInPath()
        let own = folders.map { $0.appendingPathComponent("Icon.png").standardizedFileURL.resolvingSymlinksInPath() }
        if own.contains(chosen) { return .keep }
        
        // Convert the chosen image to a real PNG
        guard let image = NSImage(contentsOf: URL(filePath: machine.icon)),
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else {
            throw MachineError.invalidIcon
        }
        return .write(png)
    }
    
    // Make the folder's Icon.png match the plan
    private func commitIcon(_ plan: IconPlan, in folder: URL) throws {
        let icon = folder.appendingPathComponent("Icon.png")
        do {
            switch plan {
            case .keep:
                break
            case .remove:
                // Only ever remove a file or a symlink, never a folder
                let values = try? icon.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                if values?.isRegularFile == true || values?.isSymbolicLink == true {
                    try FileManager.default.removeItem(at: icon)
                }
            case .write(let data):
                try data.write(to: icon, options: .atomic)
            }
        } catch {
            throw MachineError.io(error)
        }
    }
    
    // Save a cloned machine's sidecar and icon (T6 rewrites clone)
    private func saveClone(_ machine: Machine, in folder: URL) throws {
        var machine = machine
        let plan = try prepareIcon(machine, ownIcons: [folder])
        try MachineMetadata(notes: machine.notes).save(to: folder)
        try commitIcon(plan, in: folder)
        machine.icon = iconPath(in: folder)
        machine.iconCustom = !machine.icon.isEmpty
        machines.append(machine)
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
            try saveClone(cloneMachine, in: cloneMachineURL)
            
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
