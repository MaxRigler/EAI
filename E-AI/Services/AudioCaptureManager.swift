// AudioCaptureManager.swift
// AVFoundation-based audio capture for recording calls

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioCaptureManager: NSObject, ObservableObject {
    static let shared = AudioCaptureManager()
    
    // MARK: - Published Properties
    
    @Published private(set) var isRecording = false
    @Published private(set) var recordingDuration: TimeInterval = 0
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var availableInputs: [AVCaptureDevice] = []
    @Published var selectedInput: AVCaptureDevice?
    @Published private(set) var currentRecordingPath: URL?
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var durationTimer: Timer?
    private var startTime: Date?
    
    private let recordingsDirectory: URL = {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = documents.appendingPathComponent("E-AI/Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)
        return recordingsDir
    }()
    
    // MARK: - Initialization
    
    private override init() {
        super.init()
        setupAudioSession()
        loadAvailableInputs()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    self.loadAvailableInputs()
                } else {
                    self.error = AudioCaptureError.permissionDenied
                }
            }
        }
    }
    
    func loadAvailableInputs() {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInMicrophone, .externalUnknown],
            mediaType: .audio,
            position: .unspecified
        )
        
        availableInputs = discoverySession.devices
        
        // Set default input if not selected
        if selectedInput == nil {
            selectedInput = AVCaptureDevice.default(for: .audio)
        }
    }
    
    // MARK: - Recording Control
    
    func startRecording() throws {
        guard !isRecording else { return }
        
        // Generate filename
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(timestamp).m4a"
        let fileURL = recordingsDirectory.appendingPathComponent(filename)
        
        // Audio settings for high-quality recording
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self
            
            guard audioRecorder?.record() == true else {
                throw AudioCaptureError.recordingFailed
            }
            
            currentRecordingPath = fileURL
            isRecording = true
            startTime = Date()
            recordingDuration = 0
            
            // Start timers
            startTimers()
            
        } catch {
            self.error = error
            throw error
        }
    }
    
    func stopRecording() -> URL? {
        guard isRecording else { return nil }
        
        audioRecorder?.stop()
        stopTimers()
        
        isRecording = false
        let path = currentRecordingPath
        
        return path
    }
    
    func pauseRecording() {
        audioRecorder?.pause()
    }
    
    func resumeRecording() {
        audioRecorder?.record()
    }
    
    // MARK: - Input Selection
    
    func selectInput(_ device: AVCaptureDevice) {
        selectedInput = device
        // Note: Actual input switching requires recreating the audio session
        // For simplicity, we'll use the system default for now
    }
    
    // MARK: - Timer Management
    
    private func startTimers() {
        // Duration timer
        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            DispatchQueue.main.async {
                self.recordingDuration = Date().timeIntervalSince(startTime)
            }
        }
        
        // Level meter timer
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            recorder.updateMeters()
            
            // Convert decibels to 0-1 range
            let level = recorder.averagePower(forChannel: 0)
            let normalizedLevel = max(0, (level + 60) / 60) // -60dB to 0dB mapped to 0-1
            
            DispatchQueue.main.async {
                self.audioLevel = normalizedLevel
            }
        }
    }
    
    private func stopTimers() {
        durationTimer?.invalidate()
        durationTimer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }
    
    // MARK: - Utility
    
    var formattedDuration: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        let milliseconds = Int((recordingDuration.truncatingRemainder(dividingBy: 1)) * 10)
        return String(format: "%02d:%02d.%d", minutes, seconds, milliseconds)
    }
    
    var storagePath: String {
        recordingsDirectory.path
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioCaptureManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.error = AudioCaptureError.recordingFailed
            }
        }
    }
    
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            self.error = error ?? AudioCaptureError.encodingFailed
        }
    }
}

// MARK: - Audio Capture Error

enum AudioCaptureError: LocalizedError {
    case permissionDenied
    case recordingFailed
    case encodingFailed
    case noInputDevice
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone access denied. Please grant permission in System Settings."
        case .recordingFailed:
            return "Failed to start recording"
        case .encodingFailed:
            return "Audio encoding failed"
        case .noInputDevice:
            return "No audio input device available"
        }
    }
}
