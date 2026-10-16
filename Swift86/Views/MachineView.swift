//
//  MachineView.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI
import ImageIO

// MARK: - Sidebar View

// Sidebar view
struct MachineView: View {
    
    // MARK: - Environment Objects
    
    // Environment object machine library
    @EnvironmentObject var library: Library
    
    // MARK: - Properties
    
    // Machine instance
    let machine: Machine?
    
    // Environment object application settings
    @EnvironmentObject var settings: SettingsStore
    
    // Machine size
    @State private var machineSize: String?
    
    // Screenshot shown for the machine folder below, nil URL when there is none; folder is nil until listed
    @State private var screenshotFolder: String?
    @State private var screenshotURL: URL?
    
    // True when a chosen Screenshot.png is in use
    @State private var hasChosenScreenshot = false
    
    // File version of the shown screenshot, so a replaced Screenshot.png is decoded again
    @State private var screenshotStamp: Date?
    
    // Decoded screenshot and the file it came from
    @State private var screenshotImage: NSImage?
    @State private var screenshotImageURL: URL?
    
    // Bumped when the app becomes active, to look for new screenshots
    @State private var screenshotRefresh = 0
    
    // Whether the file dialog to choose a screenshot is open
    @State private var showScreenshotImporter = false
    
    // MARK: - Scene
    
    // Configure needs a stopped machine, or a running one that can open its Settings
    private func configureDisabled(_ machine: Machine) -> Bool {
        switch machine.status {
        case .stopped: return false
        case .running, .paused: return !machine.isControllable
        case .configuring: return true
        }
    }
    
    var body: some View {
        if let machine = library.machines.first(where: { $0.id == machine?.id }) {
            ScrollView {
                VStack(spacing: 0) {
                    // Screenshot preview, above the header
                    if showsScreenshot(for: machine) {
                        screenshotPreview(machine)
                            .padding(EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20))
                    }
                    
                    // Machine header title
                    HStack {
                        // Start/Stop machine
                        Button(action: {
                            library.runMachine(machine: machine)
                        }) {
                            Image(systemName: "power")
                                .imageScale(.large)
                        }
                        .disabled(machine.status != .stopped || library.isBusy(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status != .stopped || library.isBusy(machine)))
                        
                        // Machine name and status
                        VStack(alignment: .leading, spacing: 0) {
                            Text(machine.name)
                                .font(.system(.title2, design: .rounded))
                                .fontWeight(.semibold)
                            Text(machine.status == .running ? "Running" : (machine.status == .paused ? "Paused" : (machine.status == .stopped ? "Powered Off" : "Configuring")))
                                .font(.callout)
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 5)
                        
                        Spacer()
                        
                        // Edit machine details
                        Button(action: {
                            library.editMachine = machine
                        }) {
                            Image(systemName: "pencil")
                                .imageScale(.large)
                        }
                        .disabled(library.editMachine != nil)
                        .buttonStyle(MachineButtonStyle(isDisabled: library.editMachine != nil))
                        
                        // Configure machine
                        Button(action: {
                            library.configureMachine(machine: machine)
                        }) {
                            Image(systemName: "gearshape")
                                .imageScale(.large)
                        }
                        .disabled(configureDisabled(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: configureDisabled(machine)))
                        
                        // Delete machine
                        Button(action: {
                            library.pendingConfirmation = .remove(machine)
                        }) {
                            Image(systemName: "trash")
                                .imageScale(.large)
                        }
                        .disabled(machine.status != .stopped || library.isBusy(machine))
                        .buttonStyle(MachineButtonStyle(isDisabled: machine.status != .stopped || library.isBusy(machine)))
                    }
                    .padding(EdgeInsets(top: showsScreenshot(for: machine) ? 0 : 20, leading: 20, bottom: 20, trailing: 20))
                    
                    VStack(alignment: .leading, spacing: 10) {
                        // Machine description
                        Group {
                            if !machine.notes.isEmpty {
                                Text(machine.notes)
                            } else {
                                Text("Click here to add a note")
                                    .foregroundColor(.gray)
                            }
                        }
                        .panelStyle()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if machine.notes.isEmpty {
                                library.editMachine = machine
                            }
                        }

                        // Machine size
                        LabeledContent("Size", value: machineSize ?? "…")
                            .panelStyle()
                            .task(id: "\(machine.folderName)|\(machine.status)") {
                                machineSize = nil
                                let size = await sizeOf(machine.folderName)
                                guard !Task.isCancelled else { return }
                                machineSize = size
                            }
                    }
                    .padding(EdgeInsets(top: 0, leading: 20, bottom: 20, trailing: 20))
                }
            }
            .navigationSubtitle(machine.name)
            // List the screenshots off the main thread, again when the status or app focus changes
            .task(id: "\(machine.folderName)|\(machine.status)|\(settings.config.showScreenshots)|\(screenshotRefresh)|\(library.screenshotRevision)") {
                await listScreenshots(for: machine)
            }
            // Decode the shown screenshot off the main thread
            .task(id: "\(screenshotURL?.path ?? "")|\(screenshotStamp?.timeIntervalSince1970 ?? 0)") {
                await decodeScreenshot()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                screenshotRefresh += 1
            }
            .fileImporter(isPresented: $showScreenshotImporter, allowedContentTypes: [.image], allowsMultipleSelection: false) { result in
                if case .success(let urls) = result, let url = urls.first {
                    let scoped = url.startAccessingSecurityScopedResource()
                    defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                    library.chooseScreenshot(url, for: machine)
                }
            }
            .fileDialogStartingDirectory(screenshotStartingDirectory(for: machine))
        } else {
            // Welcome view
            WelcomeView()
        }
    }
}

// MARK: - Machine Size

extension MachineView {
    // Human readable folder size, calculated off the main actor
    @MainActor
    fileprivate func sizeOf(_ name: String) async -> String {
        let url = library.machinesURL.appendingPathComponent(name)
        let bytes = await Task.detached(priority: .utility) { MachineFiles.folderSize(at: url) }.value
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Screenshot

extension MachineView {
    // Whether the preview or its "No screenshot" box is shown
    fileprivate func showsScreenshot(for machine: Machine) -> Bool {
        settings.config.showScreenshots && screenshotFolder == machine.folderName
    }
    
    // The file dialog starts in screenshots/, or in the machine folder if that does not exist yet
    fileprivate func screenshotStartingDirectory(for machine: Machine) -> URL {
        let folder = library.machinesURL.appendingPathComponent(machine.folderName, isDirectory: true)
        let screenshots = folder.appendingPathComponent("screenshots", isDirectory: true)
        var isFolder: ObjCBool = false
        return FileManager.default.fileExists(atPath: screenshots.path, isDirectory: &isFolder) && isFolder.boolValue ? screenshots : folder
    }
    
    // Preview that follows the window width, or a box when there is no screenshot
    @ViewBuilder
    fileprivate func screenshotPreview(_ machine: Machine) -> some View {
        if screenshotURL == nil {
            Text("No screenshot")
                .foregroundColor(Color.white.opacity(0.6))
                .frame(maxWidth: .infinity, minHeight: 160, maxHeight: 160)
                .background(Color.black)
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                .contentShape(Rectangle())
                .onTapGesture { showScreenshotImporter = true }
                .help("Choose Screenshot…")
                .contextMenu {
                    Button("Choose Screenshot…") { showScreenshotImporter = true }
                    Button("Use Latest Screenshot") { library.useLatestScreenshot(for: machine) }
                        .disabled(!hasChosenScreenshot)
                }
        } else if let screenshotImage, screenshotImageURL == screenshotURL {
            Image(nsImage: screenshotImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)
                .contentShape(Rectangle())
                .onTapGesture { showScreenshotImporter = true }
                .help("Choose Screenshot…")
                .contextMenu {
                    Button("Choose Screenshot…") { showScreenshotImporter = true }
                    Button("Use Latest Screenshot") { library.useLatestScreenshot(for: machine) }
                        .disabled(!hasChosenScreenshot)
                }
        }
    }
    
    // Find the screenshot to show: the chosen Screenshot.png, else the most recently modified one
    @MainActor
    fileprivate func listScreenshots(for machine: Machine) async {
        let folderName = machine.folderName
        guard settings.config.showScreenshots else {
            screenshotFolder = nil
            screenshotURL = nil
            screenshotImage = nil
            return
        }
        let folder = library.machinesURL.appendingPathComponent(folderName)
        let found = await Task.detached(priority: .utility) { () -> (URL?, Bool, Date?) in
            let url = MachineFiles.displayedScreenshot(in: folder)
            let date = url.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            return (url, MachineFiles.customScreenshot(in: folder) != nil, date)
        }.value
        guard !Task.isCancelled else { return }
        
        screenshotURL = found.0
        hasChosenScreenshot = found.1
        screenshotStamp = found.2
        screenshotFolder = folderName
    }
    
    // Decode the shown screenshot downscaled, keeping the current one until the new one is ready
    @MainActor
    fileprivate func decodeScreenshot() async {
        guard let url = screenshotURL else {
            screenshotImage = nil
            screenshotImageURL = nil
            return
        }
        let image = await Task.detached(priority: .utility) { ScreenshotImage.downscaled(at: url, maxPixel: 2048) }.value
        guard !Task.isCancelled else { return }
        screenshotImage = image
        screenshotImageURL = url
    }
}

// MARK: - File Dialog Extension

extension View {
    // Open the file importer in a given folder (macOS 14 and later)
    @ViewBuilder
    fileprivate func fileDialogStartingDirectory(_ url: URL?) -> some View {
        if #available(macOS 14, *) {
            self.fileDialogDefaultDirectory(url)
        } else {
            self
        }
    }
}

// MARK: - Screenshot Image

// Image decoding for screenshots (image data only, safe off the main thread)
enum ScreenshotImage {
    
    // Downscaled copy of the image, nil if it can't be decoded
    static func downscaled(at url: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

// MARK: - Preview

struct MachineView_Previews: PreviewProvider {
    static var previews: some View {
        MachineView(machine: Machine())
            .environmentObject(Library(loadsLibrary: false))
    }
}
