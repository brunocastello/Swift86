//
//  Library.swift
//  Swift86
//
//  Created by Bruno Castelló on 03/07/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - Machine Session

// A running 86Box process and its manager socket
final class MachineSession {
    let process: Process
    let socket: ManagerSocket?
    // Settings-only (-S) sessions stay "configuring" whatever 86Box reports
    let isSettingsOnly: Bool
    // Mirrors the machine's state so a reload of the machines list can restore it
    var status: MachineStatus = .stopped
    var isControllable = false
    
    init(process: Process, socket: ManagerSocket?, isSettingsOnly: Bool = false) {
        self.process = process
        self.socket = socket
        self.isSettingsOnly = isSettingsOnly
    }
}

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
        
        // Remove the socket files on quit, the machines keep running
        NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closeAllSockets() }
        }
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
    
    // 86Box's machine list, where display names, notes and icons live
    private var vmmIniURL: URL {
        URL(fileURLWithPath: SettingsStore.shared.config.vmmIniPath)
    }
    
    // Fill in the vmm.ini keys that tie a section to its folder
    private nonisolated static func register(_ ini: inout VMMIni, section: String, folder: URL) {
        let path = MachineFiles.canonicalPath(folder)
        ini.set(path, for: "config_dir", in: section)
        ini.set(path + "/86box.cfg", for: "config_file", in: section)
        ini.set(folder.lastPathComponent.precomposedStringWithCanonicalMapping, for: "system_name", in: section)
    }
    
    // Machine as described by its vmm.ini section
    private func makeMachine(folder: URL, ini: VMMIni, existing: Machine?) -> Machine {
        let section = VMMIni.uuid(forMachineFolder: folder)
        let folderName = folder.lastPathComponent
        let display = ini.string("display_name", in: section) ?? ""
        let iconPath = ini.string("icon", in: section) ?? ""
        // Only an existing file path counts, anything else (a 86Box built-in icon name) shows the default icon
        // The image itself is loaded by the view, so a slow or evicted file can't hold up the scan
        var isFolder: ObjCBool = false
        let hasIcon = iconPath.hasPrefix("/") && FileManager.default.fileExists(atPath: iconPath, isDirectory: &isFolder) && !isFolder.boolValue
        
        var machine = Machine(
            id: existing?.id ?? UUID(),
            name: display.isEmpty ? folderName : display,
            folderName: folderName,
            iconCustom: hasIcon,
            icon: hasIcon ? iconPath : "",
            notes: ini.string("notes", in: section) ?? ""
        )
        // A running session survives reloads and machines-folder changes
        if let session = sessions[MachineFiles.canonicalPath(folder)] {
            machine.status = session.status
            machine.isControllable = session.isControllable
        } else {
            machine.status = existing?.status ?? .stopped
            machine.isControllable = false
        }
        return machine
    }
    
    // Load machines
    func load() {
        // Machines library
        var machines = [Machine]()
        
        // Identities only carry over while the machines folder is the same one
        let sameFolder = loadedMachinesURL?.standardizedFileURL == machinesURL.standardizedFileURL
        
        // List the machine folders
        guard let folders = MachineFiles.candidateFolders(in: machinesURL) else { return }
        
        // Read 86Box's machine list once
        let ini = (try? VMMIni(contentsOf: vmmIniURL)) ?? VMMIni()
        let registered = MachineFiles.registeredFolders(in: ini)
        var found = [(url: URL, section: String)]()
        
        for machineURL in folders {
            // Only folders with an 86Box config or a vmm.ini entry are machines
            guard MachineFiles.isMachineFolder(machineURL, registered: registered) else { continue }
            found.append((machineURL, VMMIni.uuid(forMachineFolder: machineURL)))
            
            // Keep the identity and status of a machine that is already loaded
            let existing = sameFolder ? self.machines.first { $0.folderName == machineURL.lastPathComponent } : nil
            machines.append(makeMachine(folder: machineURL, ini: ini, existing: existing))
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
            switch (orderIndex[first.folderName], orderIndex[last.folderName]) {
            case let (a?, b?): return a < b
            case (.some, nil): return true
            case (nil, .some): return false
            case (nil, nil): return first.name.localizedStandardCompare(last.name) == .orderedAscending
            }
        }
        
        // Return machines
        self.machines = machines
        loadedMachinesURL = machinesURL
        
        // Register and migrate (deferred, we may be inside a view update)
        DispatchQueue.main.async {
            self.registerAndMigrate(found)
        }
    }
    
    // Add the machines vmm.ini doesn't list yet and bring over notes and icons from older Swift86 versions, in one write
    private func registerAndMigrate(_ found: [(url: URL, section: String)]) {
        guard SettingsStore.shared.loadError == nil, !found.isEmpty else { return }
        
        var oldSidecars = [(url: URL, section: String, notes: String)]()
        var result = VMMIni()
        do {
            try VMMIni.update(at: vmmIniURL) { ini in
                oldSidecars = []
                for machine in found {
                    // Only a section created by this write may take anything over from the legacy plist or Icon.png
                    let existed = ini.sections().contains(machine.section)
                    if !existed { Self.register(&ini, section: machine.section, folder: machine.url) }
                    
                    // Notes: the old sidecar is authoritative, the legacy plist only fills a new section
                    let sidecar = LegacyImport.sidecarNotes(at: machine.url)
                    let action = LegacyMigration.notes(
                        sectionExisted: existed,
                        currentNotes: ini.string("notes", in: machine.section),
                        sidecarNotes: sidecar,
                        plistNotes: existed ? nil : LegacyImport.plistNotes(at: machine.url)
                    )
                    switch action {
                    case .none: break
                    case .set(let notes): ini.set(notes, for: "notes", in: machine.section)
                    case .remove: ini.set(nil, for: "notes", in: machine.section)
                    }
                    if let sidecar { oldSidecars.append((machine.url, machine.section, sidecar)) }
                    
                    // Icon: never over an existing key
                    let icon = machine.url.appendingPathComponent("Icon.png")
                    let isFile = (try? icon.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true
                    if LegacyMigration.importIcon(sectionExisted: existed, currentIcon: ini.string("icon", in: machine.section), hasIconPNG: isFile) {
                        ini.set(icon.path, for: "icon", in: machine.section)
                    }
                }
                result = ini
            }
        } catch {
            NSLog("Swift86: could not update \(vmmIniURL.path): \(error)")
            return
        }
        
        // The write went through: drop the old sidecars whose notes vmm.ini now holds
        for sidecar in oldSidecars where (result.string("notes", in: sidecar.section) ?? "") == sidecar.notes {
            LegacyImport.removeSidecar(at: sidecar.url)
        }
        
        // Show what was migrated
        for machine in found {
            guard let index = machines.firstIndex(where: { $0.folderName == machine.url.lastPathComponent }) else { continue }
            let updated = makeMachine(folder: machine.url, ini: result, existing: machines[index])
            if updated.notes != machines[index].notes || updated.icon != machines[index].icon || updated.iconCustom != machines[index].iconCustom {
                machines[index].notes = updated.notes
                machines[index].icon = updated.icon
                machines[index].iconCustom = updated.iconCustom
            }
        }
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
    
    // PNG data of the chosen custom icon, nil for the default icon
    private func convertedIcon(_ machine: Machine) throws -> Data? {
        guard machine.iconCustom, !machine.icon.isEmpty else { return nil }
        do {
            return try MachineFiles.pngData(fromImageAt: URL(fileURLWithPath: machine.icon))
        } catch {
            throw MachineError.invalidIcon
        }
    }
    
    // Create new machine
    @discardableResult
    func create(_ draft: Machine) throws -> Machine {
        // Validate the name
        let name: String
        switch MachineFiles.validateName(draft.name, in: machinesURL) {
        case .success(let valid): name = valid
        case .failure(let error): throw MachineError.invalidName(error)
        }
        
        // Check the icon before touching the file system
        let folderURL = machinesURL.appendingPathComponent(name)
        let iconData = try convertedIcon(draft)
        
        // Create the machine folder (never a 86box.cfg, 86Box makes its own)
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
        } catch {
            throw MachineError.io(error)
        }
        
        // List the machine in 86Box's machine list
        func record(_ icon: String?) throws {
            try VMMIni.update(at: vmmIniURL) { ini in
                let section = VMMIni.uuid(forMachineFolder: folderURL)
                // Whatever was listed under this folder before is stale
                ini.removeSection(section)
                Self.register(&ini, section: section, folder: folderURL)
                if !draft.notes.isEmpty { ini.set(draft.notes, for: "notes", in: section) }
                if let icon { ini.set(icon, for: "icon", in: section) }
            }
        }
        
        // Stage the icon, list the machine, then move the icon into place
        var iconPath = ""
        var listed = false
        do {
            if let iconData {
                let staged = try MachineFiles.stageIcon(iconData, in: folderURL)
                do {
                    try record(MachineFiles.iconPath(in: folderURL))
                } catch {
                    try? FileManager.default.removeItem(at: staged)
                    throw error
                }
                listed = true
                iconPath = try MachineFiles.commitIcon(staged: staged, in: folderURL)
            } else {
                try record(nil)
            }
        } catch {
            // Remove only the folder just created, and its entry if it was listed
            if listed { try? VMMIni.update(at: vmmIniURL) { $0.removeSection(VMMIni.uuid(forMachineFolder: folderURL)) } }
            try? FileManager.default.removeItem(at: folderURL)
            throw (error as? MachineFiles.IconError).map { MachineError.io($0) } ?? MachineError.io(error)
        }
        
        var machine = draft
        machine.name = name
        machine.folderName = name
        machine.status = .stopped
        machine.icon = iconPath
        machine.iconCustom = !iconPath.isEmpty
        
        // Keep the new machine at the end of the sidebar order
        machines.append(machine)
        SettingsStore.shared.config.machineOrder = machines.map(\.folderName)
        return machine
    }
    
    // MARK: - Edit Machine
    
    // Edited machine
    @Published var editMachine: Machine?
    
    // What to do with a machine's vmm.ini icon
    private enum IconPlan {
        case keep
        case remove
        case set(Data)
    }
    
    // Update an edited machine
    func update(_ edited: Machine) throws {
        // Find the machine being edited
        guard let index = machines.firstIndex(where: { $0.id == edited.id }) else {
            throw MachineError.notFound(edited.name)
        }
        let old = machines[index]
        let oldURL = machinesURL.appendingPathComponent(old.folderName)
        guard FileManager.default.fileExists(atPath: oldURL.path) else {
            throw MachineError.notFound(old.name)
        }
        
        // Validate the name, an unchanged one needs nothing
        var name = old.name
        if edited.name != old.name && edited.name.trimmingCharacters(in: .whitespacesAndNewlines) != old.name {
            switch MachineFiles.validateName(edited.name, in: machinesURL, renaming: old.folderName) {
            case .success(let valid): name = valid
            case .failure(let error): throw MachineError.invalidName(error)
            }
        }
        let nameChanged = name != old.name
        let renamed = name != old.folderName && nameChanged
        if nameChanged && old.status != .stopped { throw MachineError.machineRunning }
        
        // Decide the icon change: it only changes when the user changed it
        let iconPlan: IconPlan
        if edited.iconCustom && !edited.icon.isEmpty {
            if old.iconCustom && MachineFiles.sameFile(edited.icon, old.icon) {
                iconPlan = .keep
            } else {
                iconPlan = .set(try convertedIcon(edited) ?? Data())
            }
        } else {
            iconPlan = old.iconCustom ? .remove : .keep
        }
        
        // Rename the folder if the name changed
        let newURL = machinesURL.appendingPathComponent(name)
        let oldSection = VMMIni.uuid(forMachineFolder: oldURL)
        let finalURL = renamed ? newURL : oldURL
        
        // Icons inside the folder move with it: decide which while the old folder still exists
        let oldSpellings = MachineFiles.folderSpellings(oldURL)
        let oldIconInside = old.iconCustom && MachineFiles.isInside(old.icon, folderPaths: oldSpellings)
        let iniIconBefore = (try? VMMIni(contentsOf: vmmIniURL))?.string("icon", in: oldSection)
        let iniIconInside = iniIconBefore.map { MachineFiles.isInside($0, folderPaths: oldSpellings) } ?? false
        
        if renamed {
            do {
                try MachineFiles.renameFolder(from: oldURL, to: newURL)
            } catch {
                throw MachineError.io(error)
            }
        }
        
        // The previous icon, wherever the folder move put it
        var previousIcon: String?
        if old.iconCustom { previousIcon = renamed && oldIconInside ? MachineFiles.icon(old.icon, movedTo: newURL) : old.icon }
        
        // One write: move the section along with the folder, then apply the edits
        var otherIcons = [String]()
        func record(_ iconPath: String?) throws {
            try VMMIni.update(at: vmmIniURL) { ini in
                var section = oldSection
                if renamed {
                    section = VMMIni.uuid(forMachineFolder: newURL)
                    if section != oldSection {
                        ini.removeSection(section)
                        for entry in ini.entries(in: oldSection) { ini.setRaw(entry.raw, for: entry.key, in: section) }
                        ini.removeSection(oldSection)
                    }
                    Self.register(&ini, section: section, folder: newURL)
                    
                    // The icon file moved with the folder
                    if iniIconInside, let icon = ini.string("icon", in: section), icon == iniIconBefore {
                        ini.set(MachineFiles.icon(icon, movedTo: newURL), for: "icon", in: section)
                    }
                } else if !ini.sections().contains(section) {
                    Self.register(&ini, section: section, folder: oldURL)
                }
                
                // Renames always rename the folder, so a saved name never needs a separate display name
                if nameChanged { ini.set(nil, for: "display_name", in: section) }
                if edited.notes != old.notes { ini.set(edited.notes.isEmpty ? nil : edited.notes, for: "notes", in: section) }
                switch iconPlan {
                case .keep: break
                case .remove: ini.set(nil, for: "icon", in: section)
                case .set: ini.set(iconPath, for: "icon", in: section)
                }
                
                // Icons other machines use must survive
                otherIcons = ini.sections().filter { $0 != section }.compactMap { ini.string("icon", in: $0) }
            }
        }
        
        // A new icon is staged next to Icon.png, recorded in vmm.ini, then moved over Icon.png
        var staged: URL?
        if case .set(let data) = iconPlan {
            do {
                staged = try MachineFiles.stageIcon(data, in: finalURL)
            } catch {
                if renamed { try? MachineFiles.renameFolder(from: newURL, to: oldURL) }
                throw MachineError.io(error)
            }
        }
        do {
            try record(staged == nil ? nil : MachineFiles.iconPath(in: finalURL))
        } catch {
            // The old Icon.png stays as it is, put the folder back
            if let staged { try? FileManager.default.removeItem(at: staged) }
            if renamed { try? MachineFiles.renameFolder(from: newURL, to: oldURL) }
            throw MachineError.io(error)
        }
        
        var committedIcon: String?
        var commitError: Error?
        if let staged {
            do {
                committedIcon = try MachineFiles.commitIcon(staged: staged, in: finalURL)
            } catch {
                // vmm.ini must not point at an icon that isn't there: restore what it had
                commitError = error
                let restore = iniIconBefore.map { renamed && iniIconInside ? MachineFiles.icon($0, movedTo: newURL) : $0 }
                try? VMMIni.update(at: vmmIniURL) { $0.set(restore, for: "icon", in: VMMIni.uuid(forMachineFolder: finalURL)) }
            }
        }
        
        // Keep the machine's place in the sidebar order
        if renamed, let orderIndex = SettingsStore.shared.config.machineOrder.firstIndex(of: old.folderName) {
            SettingsStore.shared.config.machineOrder[orderIndex] = name
        }
        machines[index].name = name
        if renamed { machines[index].folderName = name }
        machines[index].notes = edited.notes
        switch iconPlan {
        case .keep:
            if let previousIcon { machines[index].icon = previousIcon }
        case .remove:
            machines[index].icon = ""
            machines[index].iconCustom = false
        case .set:
            if let committedIcon {
                machines[index].icon = committedIcon
                machines[index].iconCustom = true
            } else if let previousIcon {
                machines[index].icon = previousIcon
            }
        }
        
        // Icon.png is the one icon file: drop the one "Default icon" leaves behind and any copies earlier builds made
        switch iconPlan {
        case .keep: break
        case .remove:
            MachineFiles.removeIcon(in: finalURL, referencedBy: otherIcons)
            MachineFiles.removeLeftoverIcons(in: finalURL, referencedBy: otherIcons)
        case .set:
            if committedIcon != nil { MachineFiles.removeLeftoverIcons(in: finalURL, referencedBy: otherIcons) }
        }
        
        if let commitError { throw MachineError.io(commitError) }
    }
    
    // MARK: - Move Machine
    
    // Move machine
    func move(fromOffsets indices: IndexSet, toOffset newOffset: Int) {
        // Move machine around in sidebar list
        machines.move(fromOffsets: indices, toOffset: newOffset)
        
        // Save the folder names as the sidebar order
        SettingsStore.shared.config.machineOrder = machines.map(\.folderName)
    }
    
    // MARK: - Clone machine
    
    // Clone machine
    func clone(machine: Machine) {
        // Set base for clone machine name
        let baseTitle = machine.folderName.replacingOccurrences(of: #"\scopy\s\d+$"#, with: "", options: .regularExpression)
        
        // Count for existing clones
        let copyCount = machines.filter { $0.folderName.hasPrefix(baseTitle) }.count
        
        // Set clone machine name
        let cloneTitle = copyCount > 0 ? "\(baseTitle) copy \(copyCount)" : baseTitle
        
        let sourceFolderURL = machinesURL.appendingPathComponent(machine.folderName)
        let cloneFolderURL = machinesURL.appendingPathComponent(cloneTitle)
        // The icon file is copied with the folder, so the clone points at its own copy
        let sourceSpellings = MachineFiles.folderSpellings(sourceFolderURL)
        
        do {
            // Clone the machine contents
            let machineURL = machinesURL.appendingPathComponent(machine.folderName)
            let cloneMachineURL = cloneFolderURL
            try FileManager.default.copyItem(at: machineURL, to: cloneMachineURL)
            
            // Create the clone machine
            let cloneMachine = Machine(
                id: UUID(),
                name: cloneTitle,
                folderName: cloneTitle,
                iconCustom: machine.iconCustom,
                icon: machine.iconCustom ? MachineFiles.relocatedIcon(machine.icon, fromFolderPaths: sourceSpellings, to: cloneMachineURL) : "",
                notes: machine.notes
            )

            // List the clone, with the notes and icon of the original
            do {
                try VMMIni.update(at: vmmIniURL) { ini in
                    let source = VMMIni.uuid(forMachineFolder: machineURL)
                    let section = VMMIni.uuid(forMachineFolder: cloneMachineURL)
                    ini.removeSection(section)
                    Self.register(&ini, section: section, folder: cloneMachineURL)
                    if let value = ini.string("notes", in: source) { ini.set(value, for: "notes", in: section) }
                    if let value = ini.string("icon", in: source) {
                        ini.set(MachineFiles.relocatedIcon(value, fromFolderPaths: sourceSpellings, to: cloneMachineURL), for: "icon", in: section)
                    }
                }
            } catch {
                try? FileManager.default.removeItem(at: cloneMachineURL)
                throw error
            }
            machines.append(cloneMachine)
            
            // Keep the clone at the end of the sidebar order
            if machines.contains(where: { $0.folderName == cloneMachine.folderName }) {
                SettingsStore.shared.config.machineOrder = machines.map(\.folderName)
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
    
    // Running machine sessions, keyed by the machine folder's canonical path
    // (a machine's UUID changes on reload, the folder does not)
    private(set) var sessions: [String: MachineSession] = [:]
    
    // Machine waiting for the Kill confirmation
    @Published var pendingKill: Machine?
    
    // Session key of a machine
    private func sessionKey(_ machine: Machine) -> String {
        MachineFiles.canonicalPath(machinesURL.appendingPathComponent(machine.folderName))
    }
    
    // Running session of a machine, if any
    private func session(for machine: Machine) -> MachineSession? {
        sessions[sessionKey(machine)]
    }
    
    // Set a machine's status and control flag, in its session and in the list
    private func setState(of key: String, status: MachineStatus? = nil, controllable: Bool? = nil) {
        if let status { sessions[key]?.status = status }
        if let controllable { sessions[key]?.isControllable = controllable }
        guard let index = machines.firstIndex(where: { sessionKey($0) == key }) else { return }
        if let status { machines[index].status = status }
        if let controllable { machines[index].isControllable = controllable }
    }
    
    // Forget a session once its process ended
    private func sessionEnded(_ key: String, process: Process) {
        // A newer session may have replaced this one
        guard sessions[key]?.process === process else { return }
        sessions[key]?.socket?.close()
        sessions.removeValue(forKey: key)
        setState(of: key, status: .stopped, controllable: false)
    }
    
    // The emulator's major-version based protocol choice (official from 86Box 5.0)
    private func detectProtocol() -> ManagerProtocol {
        let appURL = URL(filePath: SettingsStore.shared.config.emulatorPath)
        let version = ManagerProtocol.version(ofApp: appURL)
        let chosen = ManagerProtocol.forVersion(version)
        NSLog("Swift86: 86Box version \(version ?? "unknown"), using the \(chosen == .official ? "official" : "legacy") manager protocol")
        return chosen
    }
    
    // Create the manager socket for a launch, wire its callbacks and set the environment
    // A legacy 86Box exits before the socket code in settings-only mode, so it gets none
    private func makeSession(key: String, process: Process, settingsOnly: Bool) -> MachineSession {
        let managerProtocol = detectProtocol()
        var socket: ManagerSocket?
        if !(settingsOnly && managerProtocol == .legacy) {
            do {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Swift86"
                socket = try ManagerSocket(protocol: managerProtocol, version: version)
            } catch {
                NSLog("Swift86: could not create the manager socket, starting without control: \(error)")
            }
        }
        // Only the chosen variable is set, and only with a socket
        process.environment = ManagerProtocol.environment(inherited: ProcessInfo.processInfo.environment, socketPath: socket?.path, protocol: managerProtocol)
        
        let session = MachineSession(process: process, socket: socket, isSettingsOnly: settingsOnly)
        
        socket?.onConnectionChange = { [weak self, weak session] connected in
            guard let self, let session, self.sessions[key] === session else { return }
            if !session.isSettingsOnly { self.setState(of: key, controllable: connected) }
        }
        if managerProtocol == .official {
            socket?.onRunningStateChange = { [weak self, weak session] state in
                guard let self, let session, self.sessions[key] === session, !session.isSettingsOnly else { return }
                switch state {
                case .running, .runningWaiting: self.setState(of: key, status: .running)
                case .paused, .pausedWaiting: self.setState(of: key, status: .paused)
                }
            }
        }
        
        // Handle process termination (set before run so a quick exit is not missed)
        process.terminationHandler = { [weak self] process in
            DispatchQueue.main.async {
                self?.sessionEnded(key, process: process)
            }
        }
        return session
    }
    
    // Run machine
    func runMachine(machine: Machine) {
        // One process per machine: a session means it is already running or being configured
        let key = sessionKey(machine)
        guard sessions[key] == nil else { return }
        
        // Prepare process to run machine
        let process = Process()
        process.executableURL = emulatorURL
        process.arguments = [
            "-R", romsURL.path,
            "-V", machine.name,
            "-P", machinesURL.appendingPathComponent(machine.folderName).path
        ]
        
        let session = makeSession(key: key, process: process, settingsOnly: false)
        
        do {
            // Start process
            try process.run()
            
            // Record the start time in 86Box's machine list, like its own manager does
            recordStart(of: machinesURL.appendingPathComponent(machine.folderName))
            
            // Add the running process to the sessions
            sessions[key] = session
            
            // Update machine status to running
            setState(of: key, status: .running, controllable: false)
        } catch {
            session.socket?.close()
            
            // Error running machine
            self.alertTitle = NSLocalizedString("An error occurred", comment: "")
            self.alertMessage = NSLocalizedString(error.localizedDescription, comment: "")
            self.alertOK = { }
            self.showCancel = false
            self.showAlert = true
        }
    }
    
    // MARK: - Control Machine
    
    // Send a command to a running machine, true when it was sent
    @discardableResult
    private func send(_ command: ManagerCommand, to machine: Machine) -> Bool {
        guard let session = session(for: machine), let socket = session.socket else { return false }
        guard socket.send(command) else {
            NSLog("Swift86: could not send \"\(command.rawValue)\" to \"\(machine.name)\"")
            return false
        }
        return true
    }
    
    // Pause or resume, legacy 86Box only toggles and never reports the state back
    func togglePause(_ machine: Machine) {
        guard send(.pause, to: machine) else { return }
        // An official 86Box reports its state, only the legacy protocol needs a local flip
        guard session(for: machine)?.socket?.managerProtocol == .legacy,
              let index = machines.firstIndex(where: { $0.id == machine.id }) else { return }
        switch machines[index].status {
        case .running: machines[index].status = .paused
        case .paused: machines[index].status = .running
        default: break
        }
    }
    
    // Hard reset (the paused state is left as is, 86Box does not report it)
    func hardReset(_ machine: Machine) {
        send(.reset, to: machine)
    }
    
    // Send Ctrl+Alt+Del to the guest
    func ctrlAltDel(_ machine: Machine) {
        send(.cad, to: machine)
    }
    
    // Shut down without 86Box's confirmation prompt
    func forceShutdown(_ machine: Machine) {
        send(.forceShutdown, to: machine)
    }
    
    // Last resort: terminate the process, the termination handler cleans up
    func kill(_ machine: Machine) {
        guard let process = session(for: machine)?.process, process.isRunning else { return }
        Darwin.kill(process.processIdentifier, SIGKILL)
    }
    
    // Close every socket when the app quits, the machines keep running
    private func closeAllSockets() {
        for session in sessions.values { session.socket?.close() }
    }
    
    // Set the section's timestamp to now (off the main thread, a busy lock must not freeze the UI)
    private func recordStart(of folder: URL) {
        let iniURL = vmmIniURL
        let stamp = ISO8601DateFormatter().string(from: Date())
        Task.detached(priority: .utility) {
            do {
                try VMMIni.update(at: iniURL) { ini in
                    let section = VMMIni.uuid(forMachineFolder: folder)
                    if !ini.sections().contains(section) { Self.register(&ini, section: section, folder: folder) }
                    ini.set(stamp, for: "timestamp", in: section)
                }
            } catch {
                NSLog("Swift86: could not record the start time: \(error)")
            }
        }
    }
    
    // MARK: - Configure Machine
    
    // Configure machine
    func configureMachine(machine: Machine) {
        // A machine with a session never gets a second process: a controllable one opens its Settings in place
        let key = sessionKey(machine)
        if let existing = sessions[key] {
            if existing.isControllable && !existing.isSettingsOnly { send(.showSettings, to: machine) }
            return
        }
        
        // Prepare process to configure machine
        let process = Process()
        process.executableURL = emulatorURL
        process.arguments = [
            "-R", romsURL.path,
            "-V", machine.name,
            "-P", machinesURL.appendingPathComponent(machine.folderName).path,
            "-S"
        ]
        
        let session = makeSession(key: key, process: process, settingsOnly: true)

        do {
            // Start process
            try process.run()

            // Add the running process to the sessions (only an official 86Box has a socket here)
            sessions[key] = session
            
            // Update machine status to configuring
            setState(of: key, status: .configuring, controllable: false)
        } catch {
            session.socket?.close()
            
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
        NSWorkspace.shared.selectFile(machinesURL.appendingPathComponent(machine.folderName).path, inFileViewerRootedAtPath: "")
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
            let machineURL = self.machinesURL.appendingPathComponent(machine.folderName)
            let section = VMMIni.uuid(forMachineFolder: machineURL)
            
            do {
                // Delete the machine
                try FileManager.default.removeItem(at: machineURL)
                self.machines.removeAll(where: { $0.id == machine.id })
                SettingsStore.shared.config.machineOrder.removeAll { $0 == machine.folderName }
                
                // Take it off 86Box's machine list too
                do {
                    try VMMIni.update(at: self.vmmIniURL) { $0.removeSection(section) }
                } catch {
                    NSLog("Swift86: could not remove the machine from \(self.vmmIniURL.path): \(error)")
                }
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
    
    // MARK: - Scan for Machines
    
    // A vmm.ini entry whose machine folder is gone
    struct StaleEntry: Identifiable {
        let id: String
        let name: String
    }
    
    // Result of the last scan, nil when there is nothing to show
    @Published var staleEntries: [StaleEntry]?
    
    // Scan from the File menu
    func scan() {
        staleEntries = scanForMachines()
    }
    
    // Reload and register the machines, then list the entries of the machines folder whose folders no longer exist
    func scanForMachines() -> [StaleEntry] {
        load()
        
        // Only judge entries while the machines folder itself can be listed
        guard MachineFiles.candidateFolders(in: machinesURL) != nil,
              let ini = try? VMMIni(contentsOf: vmmIniURL) else { return [] }
        let machinesPath = MachineFiles.canonicalPath(machinesURL)
        
        var stale = [StaleEntry]()
        for section in ini.sections() {
            guard let dir = ini.string("config_dir", in: section), !dir.isEmpty,
                  Self.isStale(configDir: dir, machinesPath: machinesPath) else { continue }
            let name = ini.string("system_name", in: section) ?? ""
            stale.append(StaleEntry(id: section, name: name.isEmpty ? (dir as NSString).lastPathComponent : name))
        }
        return stale
    }
    
    // A config_dir directly inside the machines folder whose folder is gone (symlinks are not followed)
    private static func isStale(configDir dir: String, machinesPath: String) -> Bool {
        let trimmed = RegisteredFolders.normalized(dir)
        let parent = (trimmed as NSString).deletingLastPathComponent
        let parentPath = VMMIni.canonicalPathString(URL(fileURLWithPath: parent)) ?? parent
        guard RegisteredFolders.normalized(parentPath) == machinesPath else { return false }
        var info = stat()
        return lstat(dir, &info) != 0 && errno == ENOENT
    }
    
    // Take the entries off 86Box's machine list, if their folders are still gone
    func removeStaleEntries(_ entries: [StaleEntry]) throws {
        let machinesPath = MachineFiles.canonicalPath(machinesURL)
        try VMMIni.update(at: vmmIniURL) { ini in
            for entry in entries {
                guard let dir = ini.string("config_dir", in: entry.id), Self.isStale(configDir: dir, machinesPath: machinesPath) else { continue }
                ini.removeSection(entry.id)
            }
        }
    }
    
    // Remove them, showing any error in the shared alert
    func removeStale(_ entries: [StaleEntry]) {
        do {
            try removeStaleEntries(entries)
        } catch {
            // Deferred, the confirmation alert is still closing
            DispatchQueue.main.async {
                self.alertTitle = NSLocalizedString("An error occurred", comment: "")
                self.alertMessage = error.localizedDescription
                self.alertOK = { }
                self.showCancel = false
                self.showAlert = true
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
