//
//  PathControl.swift
//  Swift86
//
//  Created by Bruno Castelló on 23/06/23.
//

// Import necessary frameworks and libraries
import SwiftUI

// MARK: - PathControl

// Path bar like Finder
struct PathControl: NSViewRepresentable {

    // MARK: - Properties

    // Path
    @Binding var path: String?

    // MARK: - Methods

    // Creates the NSPathControl and sets its properties
    func makeNSView(context: Context) -> NSPathControl {
        let pathControl = NSPathControl()
        pathControl.pathStyle = .standard
        pathControl.focusRingType = .none
        
        // Set the action for the NSPathControl
        pathControl.action = #selector(Coordinator.pathControlClicked(_:))
        pathControl.target = context.coordinator

        return pathControl
    }

    // Updates the NSPathControl with the current path
    func updateNSView(_ nsView: NSPathControl, context: Context) {
        if let path = expandPath(path) {
            nsView.url = URL(fileURLWithPath: path)
        }
    }

    // Interpret user home folder paths
    private func expandPath(_ path: String?) -> String? {
        if let path = path {
            if path.hasPrefix("~") {
                let homeDirectoryPath = (path as NSString).expandingTildeInPath
                return homeDirectoryPath
            }
            return path
        }
        return nil
    }

    // Creates a Coordinator object to handle user interaction with the NSPathControl
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    // Handles user interaction with the NSPathControl
    class Coordinator: NSObject {

        // MARK: - Properties

        // Parent path
        let parent: PathControl

        // Initialize PathControl
        init(_ parent: PathControl) {
            self.parent = parent
        }

        // MARK: - Methods

        // This function is called when the user clicks on the NSPathControl
        @objc func pathControlClicked(_ sender: NSPathControl) {
            if let clickedPathItem = sender.clickedPathItem,
               let url = clickedPathItem.url {
                parent.path = url.path
            }
        }
    }
}
