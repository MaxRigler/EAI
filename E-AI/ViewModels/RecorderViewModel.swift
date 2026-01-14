// RecorderViewModel.swift
// Recording state management

import Foundation
import AVFoundation
import Combine

// MARK: - Validation Error

enum RecordingValidationError: String, CaseIterable {
    case missingRecordingType = "Please select a recording type"
    case noSpeakersAssigned = "Please assign at least one speaker"
}

@MainActor
class RecorderViewModel: ObservableObject {
    static let shared = RecorderViewModel()
    
    // MARK: - Published Properties
    
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevel: Float = 0
    @Published var hasUnprocessedRecording = false
    
    @Published var availableInputs: [AVCaptureDevice] = []
    @Published var selectedInput: AVCaptureDevice?
    
    @Published var selectedRecordingType: RecordingType?
    @Published var speakerAssignments: [Int: CRMContact] = [:]
    @Published var recordingContext: String = ""  // Additional context for AI prompts
    
    // Speaker management - which speaker slots are active
    @Published var activeSpeakers: [Int] = [1] // Start with Speaker 1 (user)
    
    // Stop recording modal
    @Published var showStopRecordingModal = false
    @Published var pendingRecordingPath: URL?
    @Published var validationErrors: [RecordingValidationError] = []
    
    @Published var error: Error?
    
    // MARK: - Private Properties
    
    private let audioManager = AudioCaptureManager.shared
    private let recordingRepository = RecordingRepository()
    private let dailyRepository = DailyRepository()
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        setupBindings()
        // Don't load recording types here - defer until needed
    }
    
    private func setupBindings() {
        // Bind to AudioCaptureManager
        audioManager.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: &$isRecording)
        
        audioManager.$recordingDuration
            .receive(on: DispatchQueue.main)
            .assign(to: &$recordingDuration)
        
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        audioManager.$availableInputs
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableInputs)
        
        audioManager.$selectedInput
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedInput)
    }
    
    // MARK: - Recording Types
    
    @Published var recordingTypes: [RecordingType] = []
    
    func loadRecordingTypes() {
        Task {
            do {
                recordingTypes = try await dailyRepository.fetchRecordingTypes()
                if selectedRecordingType == nil {
                    selectedRecordingType = recordingTypes.first
                }
            } catch {
                self.error = error
            }
        }
    }
    
    // MARK: - Speaker Management
    
    func addSpeaker() {
        guard activeSpeakers.count < 5 else { return }
        let nextSpeaker = (activeSpeakers.max() ?? 0) + 1
        if nextSpeaker <= 5 {
            activeSpeakers.append(nextSpeaker)
            activeSpeakers.sort()
        }
    }
    
    func removeSpeaker(_ speakerNumber: Int) {
        // Can't remove Speaker 1 (the user)
        guard speakerNumber != 1 else { return }
        activeSpeakers.removeAll { $0 == speakerNumber }
        speakerAssignments.removeValue(forKey: speakerNumber)
    }
    
    // MARK: - Recording Control
    
    func startRecording() {
        do {
            try audioManager.startRecording()
            hasUnprocessedRecording = true
            // Reset speakers to just Speaker 1 for new recording
            activeSpeakers = [1]
            speakerAssignments = [:]
        } catch {
            self.error = error
        }
    }
    
    func stopRecording() {
        guard let filePath = audioManager.stopRecording() else { return }
        
        pendingRecordingPath = filePath
        
        // Always show confirmation screen after stopping
        showStopRecordingModal = true
        hasUnprocessedRecording = true
    }
    
    /// Discard the current pending recording without saving
    func discardRecording() {
        // Delete the audio file if it exists
        if let filePath = pendingRecordingPath {
            try? FileManager.default.removeItem(at: filePath)
        }
        
        // Reset state
        pendingRecordingPath = nil
        showStopRecordingModal = false
        validationErrors = []
        hasUnprocessedRecording = false
        speakerAssignments = [:]
        activeSpeakers = [1]
        recordingContext = ""
    }
    
    func validateRecording() -> [RecordingValidationError] {
        var errors: [RecordingValidationError] = []
        
        if selectedRecordingType == nil {
            errors.append(.missingRecordingType)
        }
        
        // Check if at least one non-user speaker is assigned (Speaker 2+)
        let hasNonUserSpeaker = activeSpeakers.contains { $0 > 1 }
        let assignedSpeakers = speakerAssignments.filter { $0.key > 1 }
        if hasNonUserSpeaker && assignedSpeakers.isEmpty {
            errors.append(.noSpeakersAssigned)
        }
        
        return errors
    }
    
    func completeRecording() {
        guard let filePath = pendingRecordingPath else { return }
        
        showStopRecordingModal = false
        validationErrors = []
        
        Task {
            await saveAndProcessRecording(filePath: filePath)
        }
    }
    
    func cancelStopRecording() {
        // User wants to resume - discard pending path
        showStopRecordingModal = false
        validationErrors = []
        // Keep pendingRecordingPath in case they stop again
    }
    
    func selectInput(_ device: AVCaptureDevice) {
        audioManager.selectInput(device)
    }
    
    func assignSpeaker(_ speakerNumber: Int, to contact: CRMContact?) {
        speakerAssignments[speakerNumber] = contact
    }
    
    // MARK: - Processing
    
    private func saveAndProcessRecording(filePath: URL) async {
        do {
            // Create recording record
            let recording = Recording(
                id: UUID(),
                filePath: filePath.path,
                durationSeconds: Int(recordingDuration),
                recordingTypeId: selectedRecordingType?.id,
                status: .processing,
                errorMessage: nil,
                retryCount: 0,
                context: recordingContext.isEmpty ? nil : recordingContext,
                createdAt: Date(),
                updatedAt: nil
            )
            
            let saved = try await recordingRepository.createRecording(recording)
            
            // Create speaker assignments
            for (speakerNumber, contact) in speakerAssignments {
                let speaker = RecordingSpeaker(
                    id: UUID(),
                    recordingId: saved.id,
                    speakerNumber: speakerNumber,
                    contactId: contact.id,
                    isUser: speakerNumber == 1
                )
                _ = try await recordingRepository.createRecordingSpeaker(speaker)
            }
            
            // Reset state
            speakerAssignments = [:]
            activeSpeakers = [1]
            hasUnprocessedRecording = false
            pendingRecordingPath = nil
            recordingContext = ""
            
            // Enqueue for background processing (transcription, summarization, embeddings)
            await ProcessingQueue.shared.enqueue(recordingId: saved.id)
            
        } catch {
            self.error = error
        }
    }
    
    // MARK: - Computed Properties
    
    var formattedDuration: String {
        audioManager.formattedDuration
    }
    
    var isSystemAudioEnabled: Bool {
        // Placeholder - actual system audio capture requires ScreenCaptureKit
        return true
    }
    
    var canAddSpeaker: Bool {
        activeSpeakers.count < 5
    }
}

