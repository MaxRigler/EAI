// E_AIApp.swift
// Main application entry point for E-AI macOS app

import SwiftUI

@main
struct E_AIApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        // We use a custom window controller, so we don't declare a WindowGroup here
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var floatingPanelController: FloatingPanelController?
    var setupWindowController: NSWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Check if API keys are configured FIRST
        let keychainManager = KeychainManager.shared
        
        if !keychainManager.hasRequiredKeys {
            // Show setup wizard before anything else
            showSetupWizard()
        } else {
            // Keys exist - initialize and show main UI
            startApp()
        }
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false // Keep app running even if window is closed
    }
    
    private func showSetupWizard() {
        let setupView = SetupView(onComplete: { [weak self] in
            // Ensure we're on main thread and properly dispatch
            DispatchQueue.main.async {
                self?.setupWindowController?.window?.close()
                self?.setupWindowController = nil
                self?.startApp()
            }
        })
        
        let hostingController = NSHostingController(rootView: setupView)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "E-AI Setup"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 520))
        window.center()
        
        setupWindowController = NSWindowController(window: window)
        setupWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func startApp() {
        // Initialize Supabase first
        Task {
            await SupabaseManager.shared.initialize()
            
            // Start processing any pending recordings from previous sessions
            await ProcessingQueue.shared.processPendingRecordings()
            
            // Start the daily summary scheduler (runs at 11:59 PM)
            DailySummaryScheduler.shared.start()
            
            // Start email sync scheduler if Gmail is connected
            if GmailAuthService.shared.isAuthenticated {
                EmailSyncScheduler.shared.start()
                print("EmailSyncScheduler started")
            }
        }
        
        // Initialize WhisperKit model in background (can take a few seconds)
        Task {
            do {
                try await TranscriptionService.shared.initialize()
                print("WhisperKit model loaded successfully")
            } catch {
                print("Failed to load WhisperKit model: \(error)")
            }
        }
        
        // Create and show the floating panel immediately
        // (Supabase init and WhisperKit loading happen in background)
        floatingPanelController = FloatingPanelController()
        floatingPanelController?.showWindow(nil)
        
        // Make sure the panel is visible
        if let window = floatingPanelController?.window {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        
        NSApp.activate(ignoringOtherApps: true)
    }
}
