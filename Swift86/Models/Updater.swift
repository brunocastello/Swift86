//
//  Updater.swift
//  Swift86
//
//  Created by Bruno Castelló on 17/10/26.
//

// Import necessary frameworks and libraries
import Foundation
import Observation
import Sparkle

// MARK: - Updater

// Wraps Sparkle's standard updater; the setting itself lives in Settings.json
@MainActor @Observable final class Updater {
    
    // MARK: - Properties
    
    // Whether a check can be started right now
    private(set) var canCheckForUpdates = false
    
    // Sparkle's standard controller, with its own AppKit update windows
    @ObservationIgnored private let controller: SPUStandardUpdaterController
    
    // Keeps canCheckForUpdates in sync with Sparkle
    @ObservationIgnored private var observation: NSKeyValueObservation?
    
    // Whether Sparkle checks for updates automatically
    var automaticallyChecks: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }
    
    // MARK: - Initialization
    
    init() {
        controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        
        // Apply the persisted setting; updates are never installed without asking
        controller.updater.automaticallyChecksForUpdates = SettingsStore.shared.config.checkForUpdates
        controller.updater.automaticallyDownloadsUpdates = false
        
        // Follow Sparkle's canCheckForUpdates
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            let value = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = value }
        }
    }
    
    // MARK: - Methods
    
    // Check now, showing Sparkle's UI
    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
