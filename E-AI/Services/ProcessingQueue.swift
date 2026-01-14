// ProcessingQueue.swift
// Background processing queue for recordings

import Foundation

/// Actor-based background queue for processing recordings
/// Handles transcription, summarization, task extraction, and embedding generation
/// Implements retry logic with exponential backoff
actor ProcessingQueue {
    static let shared = ProcessingQueue()
    
    // MARK: - Types
    
    struct ProcessingJob {
        let recordingId: UUID
        var attemptNumber: Int = 0
        var scheduledAt: Date = Date()
    }
    
    enum ProcessingStage: String {
        case transcribing
        case summarizing
        case embedding
        case complete
        case failed
    }
    
    // MARK: - Properties
    
    private var pendingJobs: [ProcessingJob] = []
    private var isProcessing = false
    private let maxRetries = 3
    private let retryDelays: [TimeInterval] = [1, 5, 15]  // Exponential backoff
    
    private let recordingRepository = RecordingRepository()
    private let taskRepository = TaskRepository()
    
    private init() {}
    
    // MARK: - Public API
    
    /// Add a recording to the processing queue
    func enqueue(recordingId: UUID) {
        let job = ProcessingJob(recordingId: recordingId)
        pendingJobs.append(job)
        print("ProcessingQueue: Enqueued recording \(recordingId)")
        
        // Start processing if not already running
        Task {
            await processNextIfIdle()
        }
    }
    
    /// Retry a failed recording
    func retryFailed(recordingId: UUID) async {
        // Reset the recording status
        do {
            try await recordingRepository.updateRecordingStatus(
                id: recordingId,
                status: .processing,
                errorMessage: nil
            )
            try await recordingRepository.resetRetryCount(id: recordingId)
            enqueue(recordingId: recordingId)
        } catch {
            print("ProcessingQueue: Failed to retry recording \(recordingId): \(error)")
        }
    }
    
    /// Process any pending recordings (call on app startup)
    func processPendingRecordings() async {
        do {
            let pending = try await recordingRepository.fetchPendingRecordings()
            for recording in pending {
                enqueue(recordingId: recording.id)
            }
            print("ProcessingQueue: Found \(pending.count) pending recordings")
        } catch {
            print("ProcessingQueue: Failed to fetch pending recordings: \(error)")
        }
    }
    
    // MARK: - Private Processing
    
    private func processNextIfIdle() async {
        guard !isProcessing, !pendingJobs.isEmpty else { return }
        
        isProcessing = true
        
        while let job = getNextReadyJob() {
            await processJob(job)
        }
        
        isProcessing = false
    }
    
    private func getNextReadyJob() -> ProcessingJob? {
        let now = Date()
        if let index = pendingJobs.firstIndex(where: { $0.scheduledAt <= now }) {
            return pendingJobs.remove(at: index)
        }
        return nil
    }
    
    private func processJob(_ job: ProcessingJob) async {
        let recordingId = job.recordingId
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] ProcessingQueue: ▶️ Starting job for recording \(recordingId) (attempt \(job.attemptNumber + 1)/\(maxRetries))")
        
        do {
            // Fetch the recording and its details
            print("[\(timestamp)] ProcessingQueue: 📥 Fetching recording details...")
            guard let recording = try await recordingRepository.fetchRecording(id: recordingId) else {
                print("[\(timestamp)] ProcessingQueue: ❌ Recording \(recordingId) not found in database")
                return
            }
            print("[\(timestamp)] ProcessingQueue: ✅ Found recording at path: \(recording.filePath)")
            
            let speakers = try await recordingRepository.fetchRecordingSpeakers(recordingId: recordingId)
            print("[\(timestamp)] ProcessingQueue: 👥 Found \(speakers.count) speaker(s)")
            
            let recordingType = try await fetchRecordingType(id: recording.recordingTypeId)
            print("[\(timestamp)] ProcessingQueue: 🏷️ Recording type: \(recordingType?.name ?? "None")")
            
            // Build speaker -> contact map
            var speakerContactMap: [Int: UUID] = [:]
            for speaker in speakers {
                if let contactId = speaker.contactId {
                    speakerContactMap[speaker.speakerNumber] = contactId
                }
            }
            
            // Check for existing transcript (resume support)
            var transcript: Transcript? = try await recordingRepository.fetchTranscript(recordingId: recordingId)
            
            // Stage 1: Transcription (skip if already exists)
            if let existingTranscript = transcript {
                print("[\(timestamp)] ProcessingQueue: ⏭️ STAGE 1: Transcript already exists - skipping transcription")
            } else {
                print("[\(timestamp)] ProcessingQueue: 🎙️ STAGE 1: Starting transcription...")
                try await updateStatus(recordingId: recordingId, status: .transcribing)
                
                // Check if WhisperKit is ready
                let isModelLoaded = await TranscriptionService.shared.isModelLoaded
                print("[\(timestamp)] ProcessingQueue: 🤖 WhisperKit model loaded: \(isModelLoaded)")
                
                if !isModelLoaded {
                    print("[\(timestamp)] ProcessingQueue: ⏳ Waiting for WhisperKit model to load...")
                    try await TranscriptionService.shared.initialize()
                    print("[\(timestamp)] ProcessingQueue: ✅ WhisperKit model now loaded")
                }
                
                let audioURL = URL(fileURLWithPath: recording.filePath)
                print("[\(timestamp)] ProcessingQueue: 🎵 Transcribing audio file: \(audioURL.lastPathComponent)")
                
                let transcriptionResult = try await TranscriptionService.shared.transcribe(
                    audioURL: audioURL,
                    speakers: speakers
                )
                print("[\(timestamp)] ProcessingQueue: ✅ Transcription complete (\(transcriptionResult.segments.count) segments, \(transcriptionResult.fullText.count) chars)")
                
                transcript = try await saveTranscript(
                    recordingId: recordingId,
                    result: transcriptionResult
                )
                print("[\(timestamp)] ProcessingQueue: 💾 Transcript saved to database")
            }
            
            guard let transcript = transcript else {
                throw ProcessingError.transcriptionFailed("No transcript available")
            }
            
            // Check for existing summary (resume support)
            var summary: Summary? = try await recordingRepository.fetchSummary(recordingId: recordingId)
            
            // Stage 2: Summarization (skip if already exists)
            if let existingSummary = summary {
                print("[\(timestamp)] ProcessingQueue: ⏭️ STAGE 2: Summary already exists - skipping summarization")
            } else {
                print("[\(timestamp)] ProcessingQueue: 📝 STAGE 2: Starting summarization...")
                try await updateStatus(recordingId: recordingId, status: .summarizing)
                
                guard let recordingType = recordingType else {
                    print("[\(timestamp)] ProcessingQueue: ❌ No recording type - cannot summarize")
                    throw ProcessingError.missingRecordingType
                }
                
                // Check Claude API key
                let hasClaudeKey = KeychainManager.shared.claudeAPIKey != nil
                print("[\(timestamp)] ProcessingQueue: 🔑 Claude API key configured: \(hasClaudeKey)")
                
                let summarizationResult = try await SummarizationService.shared.summarize(
                    transcript: transcript,
                    recordingType: recordingType,
                    context: recording.context
                )
                print("[\(timestamp)] ProcessingQueue: ✅ Summarization complete (\(summarizationResult.summaryText.count) chars)")
                
                summary = try await saveSummary(
                    recordingId: recordingId,
                    result: summarizationResult
                )
                print("[\(timestamp)] ProcessingQueue: 💾 Summary saved to database")
            }
            
            guard let summary = summary else {
                throw ProcessingError.summarizationFailed("No summary available")
            }
            
            // Stage 3: Task Extraction
            print("[\(timestamp)] ProcessingQueue: ✅ STAGE 3: Extracting tasks...")
            let extractedTasks = try await SummarizationService.shared.extractTasks(
                transcript: transcript,
                speakerContactMap: speakerContactMap
            )
            print("[\(timestamp)] ProcessingQueue: ✅ Extracted \(extractedTasks.count) task(s)")
            
            try await saveTasks(
                extractedTasks: extractedTasks,
                recordingId: recordingId
            )
            
            // Stage 4: Generate Embeddings
            print("[\(timestamp)] ProcessingQueue: 🧮 STAGE 4: Generating embeddings...")
            
            // Check OpenAI API key
            let hasOpenAIKey = KeychainManager.shared.openaiAPIKey != nil
            print("[\(timestamp)] ProcessingQueue: 🔑 OpenAI API key configured: \(hasOpenAIKey)")
            
            try await generateAndSaveEmbeddings(
                transcript: transcript,
                summary: summary
            )
            print("[\(timestamp)] ProcessingQueue: ✅ Embeddings generated and saved")
            
            // Mark complete
            try await updateStatus(recordingId: recordingId, status: .complete)
            print("[\(timestamp)] ProcessingQueue: 🎉 COMPLETE - Recording \(recordingId) fully processed!")
            
        } catch {
            print("[\(timestamp)] ProcessingQueue: ❌ ERROR: \(error.localizedDescription)")
            await handleProcessingError(job: job, error: error)
        }
    }
    
    private func handleProcessingError(job: ProcessingJob, error: Error) async {
        let recordingId = job.recordingId
        print("ProcessingQueue: Error processing \(recordingId): \(error)")
        
        var updatedJob = job
        updatedJob.attemptNumber += 1
        
        if updatedJob.attemptNumber < maxRetries {
            // Schedule retry with exponential backoff
            let delay = retryDelays[min(updatedJob.attemptNumber - 1, retryDelays.count - 1)]
            updatedJob.scheduledAt = Date().addingTimeInterval(delay)
            pendingJobs.append(updatedJob)
            
            print("ProcessingQueue: Scheduled retry \(updatedJob.attemptNumber) for \(recordingId) in \(delay)s")
            
            do {
                try await recordingRepository.incrementRetryCount(id: recordingId)
            } catch {
                print("ProcessingQueue: Failed to increment retry count: \(error)")
            }
        } else {
            // Mark as failed after exhausting retries
            do {
                try await updateStatus(
                    recordingId: recordingId,
                    status: .failed,
                    errorMessage: error.localizedDescription
                )
                print("ProcessingQueue: Recording \(recordingId) marked as failed")
            } catch {
                print("ProcessingQueue: Failed to update status to failed: \(error)")
            }
        }
    }
    
    // MARK: - Database Operations
    
    private func updateStatus(
        recordingId: UUID,
        status: RecordingStatus,
        errorMessage: String? = nil
    ) async throws {
        try await recordingRepository.updateRecordingStatus(
            id: recordingId,
            status: status,
            errorMessage: errorMessage
        )
    }
    
    private func fetchRecordingType(id: UUID?) async throws -> RecordingType? {
        guard let id = id else { return nil }
        return try await recordingRepository.fetchRecordingType(id: id)
    }
    
    private func saveTranscript(
        recordingId: UUID,
        result: LocalTranscriptionResult
    ) async throws -> Transcript {
        let transcript = Transcript(
            id: UUID(),
            recordingId: recordingId,
            fullText: result.fullText,
            speakerSegments: result.segments,
            createdAt: Date()
        )
        return try await recordingRepository.createTranscript(transcript)
    }
    
    private func saveSummary(
        recordingId: UUID,
        result: SummarizationResult
    ) async throws -> Summary {
        let summary = Summary(
            id: UUID(),
            recordingId: recordingId,
            summaryText: result.summaryText,
            promptTemplateUsed: result.promptTemplateUsed,
            createdAt: Date()
        )
        return try await recordingRepository.createSummary(summary)
    }
    
    private func saveTasks(
        extractedTasks: [ExtractedTask],
        recordingId: UUID
    ) async throws {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        print("[\(timestamp)] ProcessingQueue: 📋 Starting to save \(extractedTasks.count) tasks for recording \(recordingId)...")
        
        for task in extractedTasks {
            let appTask = AppTask(
                id: UUID(),
                contactId: task.contactId,
                recordingId: recordingId,
                description: task.description,
                status: .open,
                dueDate: task.dueDate,
                createdAt: Date(),
                completedAt: nil
            )
            do {
                let created = try await taskRepository.createTask(appTask)
                let descPreview = String(created.description.prefix(50))
                print("[\(timestamp)] ProcessingQueue: ✅ Saved task '\(descPreview)...' (ID: \(created.id), contactId: \(String(describing: created.contactId)))")
            } catch {
                let descPreview = String(task.description.prefix(50))
                print("[\(timestamp)] ProcessingQueue: ❌ FAILED to save task '\(descPreview)...': \(error)")
                throw error
            }
        }
        print("[\(timestamp)] ProcessingQueue: ✅ Successfully saved all \(extractedTasks.count) tasks for recording \(recordingId)")
    }
    
    private func generateAndSaveEmbeddings(
        transcript: Transcript,
        summary: Summary
    ) async throws {
        // Generate embeddings in parallel
        async let transcriptEmbedding = EmbeddingService.shared.generateEmbedding(
            for: transcript.fullText
        )
        async let summaryEmbedding = EmbeddingService.shared.generateEmbedding(
            for: summary.summaryText
        )
        
        let (tEmbed, sEmbed) = try await (transcriptEmbedding, summaryEmbedding)
        
        // Save embeddings
        try await EmbeddingService.shared.updateTranscriptEmbedding(
            transcriptId: transcript.id,
            embedding: tEmbed
        )
        try await EmbeddingService.shared.updateSummaryEmbedding(
            summaryId: summary.id,
            embedding: sEmbed
        )
        
        print("ProcessingQueue: Generated and saved embeddings")
    }
}

// MARK: - Processing Error

enum ProcessingError: LocalizedError {
    case missingRecordingType
    case recordingNotFound
    case transcriptionFailed(String)
    case summarizationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingRecordingType:
            return "Recording type not found"
        case .recordingNotFound:
            return "Recording not found"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .summarizationFailed(let reason):
            return "Summarization failed: \(reason)"
        }
    }
}
