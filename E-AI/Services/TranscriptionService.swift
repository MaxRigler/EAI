// TranscriptionService.swift
// WhisperKit-based local transcription service

import Foundation
import WhisperKit

/// Service for transcribing audio files using WhisperKit
/// Runs entirely on-device using Apple Silicon acceleration
class TranscriptionService: ObservableObject {
    static let shared = TranscriptionService()
    
    // MARK: - Published Properties
    
    @Published private(set) var isModelLoaded = false
    @Published private(set) var isTranscribing = false
    @Published private(set) var isInitializing = false
    @Published private(set) var loadingProgress: Float = 0
    @Published private(set) var loadingStatus: String = ""
    @Published private(set) var error: Error?
    
    // MARK: - Private Properties
    
    private var whisperKit: WhisperKit?
    private let modelName = "large-v3"  // Using large model for accuracy (~1.5GB download)
    
    private init() {}
    
    // MARK: - Initialization
    
    /// Initialize WhisperKit and load the model
    /// Call this at app startup - the model will download on first run (~1.5GB)
    /// This may take several minutes on the first launch
    func initialize() async throws {
        // Prevent duplicate initialization
        guard !isModelLoaded else {
            print("TranscriptionService: Model already loaded")
            return
        }
        
        // Check if already initializing
        let alreadyInitializing = await MainActor.run { self.isInitializing }
        guard !alreadyInitializing else {
            print("TranscriptionService: Initialization already in progress, waiting...")
            // Wait for existing initialization to complete
            while await !MainActor.run(body: { self.isModelLoaded }) {
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
            }
            return
        }
        
        await MainActor.run {
            self.isInitializing = true
            self.loadingStatus = "Preparing WhisperKit..."
        }
        
        do {
            print("TranscriptionService: 🚀 Starting WhisperKit initialization...")
            print("TranscriptionService: 📦 Model: \(modelName) (~1.5GB)")
            print("TranscriptionService: ⏳ First run will download the model - this may take several minutes...")
            
            await MainActor.run {
                self.loadingStatus = "Downloading \(modelName) model..."
                self.loadingProgress = 0.1
            }
            
            // Initialize WhisperKit with the specified model
            // verbose=true shows download progress in console
            whisperKit = try await WhisperKit(
                model: modelName,
                verbose: true,  // Show download progress
                logLevel: .info  // More detailed logs during init
            )
            
            await MainActor.run {
                self.isModelLoaded = true
                self.isInitializing = false
                self.loadingProgress = 1.0
                self.loadingStatus = "Ready"
            }
            
            print("TranscriptionService: ✅ Model loaded successfully!")
            print("TranscriptionService: 🎙️ Ready to transcribe audio")
            
        } catch {
            print("TranscriptionService: ❌ Failed to load model: \(error.localizedDescription)")
            await MainActor.run {
                self.error = error
                self.isInitializing = false
                self.loadingStatus = "Failed to load"
            }
            throw TranscriptionError.modelLoadFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Transcription
    
    /// Transcribe an audio file
    /// - Parameters:
    ///   - audioURL: URL to the audio file (m4a, wav, etc.)
    ///   - speakers: Recording speakers to map to speaker numbers
    /// - Returns: Transcript with speaker segments
    func transcribe(
        audioURL: URL,
        speakers: [RecordingSpeaker]
    ) async throws -> LocalTranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }
        
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw TranscriptionError.audioFileNotFound
        }
        
        await MainActor.run {
            self.isTranscribing = true
        }
        
        defer {
            Task { @MainActor in
                self.isTranscribing = false
            }
        }
        
        do {
            print("TranscriptionService: Transcribing \(audioURL.lastPathComponent)...")
            
            // Transcribe the audio
            let results: [TranscriptionResult] = try await whisperKit.transcribe(audioPath: audioURL.path)
            
            guard let result = results.first else {
                throw TranscriptionError.noTranscriptionResult
            }
            
            // Build speaker segments from the transcription
            let segments = buildSpeakerSegments(from: result, speakers: speakers)
            
            // Combine all text
            let fullText = segments.map { segment in
                "Speaker \(segment.speaker): \(segment.text)"
            }.joined(separator: "\n\n")
            
            print("TranscriptionService: Transcription complete (\(segments.count) segments)")
            
            return LocalTranscriptionResult(
                fullText: fullText,
                segments: segments
            )
            
        } catch let error as TranscriptionError {
            throw error
        } catch {
            throw TranscriptionError.transcriptionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Dual Track Transcription
    
    /// Transcribe dual-track audio with separate speaker identification
    /// Track 1 = microphone (user), Track 2 = system audio (other participants)
    func transcribeDualTrack(
        track1URL: URL,
        track2URL: URL,
        speakers: [RecordingSpeaker]
    ) async throws -> LocalTranscriptionResult {
        guard let whisperKit = whisperKit, isModelLoaded else {
            throw TranscriptionError.modelNotLoaded
        }
        
        await MainActor.run {
            self.isTranscribing = true
        }
        
        defer {
            Task { @MainActor in
                self.isTranscribing = false
            }
        }
        
        // Find the user speaker (for track 1)
        let userSpeaker = speakers.first(where: { $0.isUser })?.speakerNumber ?? 1
        
        // Find non-user speakers (for track 2)
        let otherSpeakers = speakers.filter { !$0.isUser }
        let defaultOtherSpeaker = otherSpeakers.first?.speakerNumber ?? 2
        
        // Transcribe both tracks in parallel
        async let track1Result = whisperKit.transcribe(audioPath: track1URL.path)
        async let track2Result = whisperKit.transcribe(audioPath: track2URL.path)
        
        let (results1, results2): ([TranscriptionResult], [TranscriptionResult]) = try await (track1Result, track2Result)
        
        // Build segments from both tracks
        var allSegments: [SpeakerSegment] = []
        
        if let r1 = results1.first {
            allSegments.append(contentsOf: buildSpeakerSegmentsForTrack(
                from: r1,
                speakerNumber: userSpeaker
            ))
        }
        
        if let r2 = results2.first {
            allSegments.append(contentsOf: buildSpeakerSegmentsForTrack(
                from: r2,
                speakerNumber: defaultOtherSpeaker
            ))
        }
        
        // Sort by timestamp
        allSegments.sort { $0.start < $1.start }
        
        // Build full text with speaker labels
        let fullText = allSegments.map { segment in
            "Speaker \(segment.speaker): \(segment.text)"
        }.joined(separator: "\n\n")
        
        return LocalTranscriptionResult(
            fullText: fullText,
            segments: allSegments
        )
    }
    
    // MARK: - Private Helpers
    
    private func buildSpeakerSegments(
        from result: TranscriptionResult,
        speakers: [RecordingSpeaker]
    ) -> [SpeakerSegment] {
        // For single-track audio, we assign all to speaker 1 by default
        // In a real implementation with diarization, we'd detect speaker changes
        let defaultSpeaker = speakers.first?.speakerNumber ?? 1
        
        // WhisperKit returns segments with timing info (non-optional array)
        let whisperSegments = result.segments
        
        if whisperSegments.isEmpty {
            // Fallback: create single segment from full text
            return [SpeakerSegment(
                speaker: defaultSpeaker,
                start: 0,
                end: Double(result.text.count) / 10.0,  // Rough estimate
                text: result.text
            )]
        }
        
        return whisperSegments.enumerated().map { index, segment in
            // Alternate speakers for demo purposes when multiple speakers
            // In production, this would use actual speaker diarization
            let speakerNum = speakers.count > 1 
                ? (index % speakers.count) + 1 
                : defaultSpeaker
            
            return SpeakerSegment(
                speaker: speakerNum,
                start: Double(segment.start),
                end: Double(segment.end),
                text: segment.text
            )
        }
    }
    
    private func buildSpeakerSegmentsForTrack(
        from result: TranscriptionResult,
        speakerNumber: Int
    ) -> [SpeakerSegment] {
        let whisperSegments = result.segments
        
        if whisperSegments.isEmpty {
            return [SpeakerSegment(
                speaker: speakerNumber,
                start: 0,
                end: Double(result.text.count) / 10.0,
                text: result.text
            )]
        }
        
        return whisperSegments.map { segment in
            SpeakerSegment(
                speaker: speakerNumber,
                start: Double(segment.start),
                end: Double(segment.end),
                text: segment.text
            )
        }
    }
}

// MARK: - Local Transcription Result (our own type)

struct LocalTranscriptionResult {
    let fullText: String
    let segments: [SpeakerSegment]
}

// MARK: - Transcription Error

enum TranscriptionError: LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case audioFileNotFound
    case noTranscriptionResult
    case transcriptionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Transcription model not loaded. Please wait for initialization."
        case .modelLoadFailed(let message):
            return "Failed to load transcription model: \(message)"
        case .audioFileNotFound:
            return "Audio file not found"
        case .noTranscriptionResult:
            return "No transcription result returned"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

