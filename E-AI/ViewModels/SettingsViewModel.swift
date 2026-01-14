// SettingsViewModel.swift
// Settings state management

import Foundation
import AVFoundation
import AppKit

@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recordingTypes: [RecordingType] = []
    @Published var availableInputs: [AVCaptureDevice] = []
    @Published var defaultInput: AVCaptureDevice?
    @Published var storagePath: String = ""
    
    @Published var hasSupabaseKey = false
    @Published var hasClaudeKey = false
    @Published var hasOpenAIKey = false
    
    @Published var issues: [SettingsIssue] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    @Published var showAddRecordingType = false
    @Published var showAPIKeySetup = false
    @Published var editingRecordingType: RecordingType?
    
    // Email settings
    @Published var userDisplayName: String = "" {
        didSet {
            UserDefaults.standard.set(userDisplayName, forKey: "eai_user_display_name")
        }
    }
    
    // MARK: - Private Properties
    
    private let dailyRepository = DailyRepository()
    private let audioManager = AudioCaptureManager.shared
    private let keychainManager = KeychainManager.shared
    
    // MARK: - Computed Properties
    
    var hasIssues: Bool { !issues.isEmpty }
    var issueCount: Int { issues.count }
    var showRecordingTypeEditor: Bool { showAddRecordingType || editingRecordingType != nil }
    
    // MARK: - Load Settings
    
    func loadSettings() {
        loadRecordingTypes()
        loadAudioSettings()
        loadAPIKeyStatus()
        loadStoragePath()
        loadEmailSettings()
        loadIssues()
    }
    
    private func loadRecordingTypes() {
        Task {
            do {
                recordingTypes = try await dailyRepository.fetchAllRecordingTypes()
            } catch {
                self.error = error
            }
        }
    }
    
    private func loadAudioSettings() {
        availableInputs = audioManager.availableInputs
        defaultInput = audioManager.selectedInput
    }
    
    private func loadAPIKeyStatus() {
        hasSupabaseKey = keychainManager.supabaseURL != nil && keychainManager.supabaseKey != nil
        hasClaudeKey = keychainManager.claudeAPIKey != nil
        hasOpenAIKey = keychainManager.openaiAPIKey != nil
    }
    
    private func loadStoragePath() {
        storagePath = audioManager.storagePath
    }
    
    private func loadEmailSettings() {
        userDisplayName = UserDefaults.standard.string(forKey: "eai_user_display_name") ?? ""
    }
    
    private func loadIssues() {
        // TODO: Fetch failed recordings/transcriptions/syncs from database
        issues = []
    }
    
    // MARK: - Audio Settings
    
    func setDefaultInput(_ device: AVCaptureDevice) {
        defaultInput = device
        audioManager.selectInput(device)
    }
    
    func selectStoragePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            storagePath = url.path
            // TODO: Save to UserDefaults
        }
    }
    
    // MARK: - Recording Types
    
    func editRecordingType(_ type: RecordingType) {
        editingRecordingType = type
    }
    
    func dismissRecordingTypeEditor() {
        showAddRecordingType = false
        editingRecordingType = nil
    }
    
    func saveRecordingType(_ type: RecordingType) {
        // Capture editing state before async task runs (sheet dismiss can clear editingRecordingType)
        let isUpdating = editingRecordingType != nil
        
        Task {
            do {
                if isUpdating {
                    // Update existing
                    let updated = try await dailyRepository.updateRecordingType(type)
                    if let index = recordingTypes.firstIndex(where: { $0.id == updated.id }) {
                        recordingTypes[index] = updated
                    }
                } else {
                    // Create new
                    let created = try await dailyRepository.createRecordingType(type)
                    recordingTypes.append(created)
                    recordingTypes.sort { $0.name < $1.name }
                }
                dismissRecordingTypeEditor()
            } catch {
                self.error = error
            }
        }
    }
    
    func deleteRecordingType(_ type: RecordingType) {
        Task {
            do {
                try await dailyRepository.deleteRecordingType(id: type.id)
                recordingTypes.removeAll { $0.id == type.id }
            } catch {
                self.error = error
            }
        }
    }
    
    // MARK: - Issues
    
    func retryIssue(_ issue: SettingsIssue) {
        // TODO: Retry the failed operation
        issues.removeAll { $0.id == issue.id }
    }
    
    func dismissIssue(_ issue: SettingsIssue) {
        issues.removeAll { $0.id == issue.id }
    }
    
    // MARK: - Gmail
    
    @Published var isGmailConnected = false
    
    func refreshGmailStatus() {
        isGmailConnected = GmailAuthService.shared.isAuthenticated
        // Trigger a view refresh
        objectWillChange.send()
    }
}
