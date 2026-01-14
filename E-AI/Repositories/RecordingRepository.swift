// RecordingRepository.swift
// CRUD for recordings and related entities

import Foundation

class RecordingRepository {
    
    // MARK: - Recordings
    
    func fetchRecordings(limit: Int = 50) async throws -> [Recording] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return response
    }
    
    func fetchRecordings(for date: Date) async throws -> [Recording] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        // Get start and end of day in local timezone
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }
        
        // Format with timezone offset for Supabase (ISO8601)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        
        let startString = formatter.string(from: startOfDay)
        let endString = formatter.string(from: endOfDay)
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .gte("created_at", value: startString)
            .lt("created_at", value: endString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func fetchRecordings(contactId: UUID) async throws -> [Recording] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        // First get speaker assignments for this contact
        let speakers: [RecordingSpeaker] = try await client
            .from("recording_speakers")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .value
        
        let recordingIds = speakers.map { $0.recordingId.uuidString }
        
        guard !recordingIds.isEmpty else { return [] }
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .in("id", values: recordingIds)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func createRecording(_ recording: Recording) async throws -> Recording {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Recording] = try await client
            .from("recordings")
            .insert(recording)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    // MARK: - Recording Speakers
    
    func createRecordingSpeaker(_ speaker: RecordingSpeaker) async throws -> RecordingSpeaker {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [RecordingSpeaker] = try await client
            .from("recording_speakers")
            .insert(speaker)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    // MARK: - Transcripts
    
    func fetchTranscript(recordingId: UUID) async throws -> Transcript? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [Transcript] = try await client
            .from("transcripts")
            .select()
            .eq("recording_id", value: recordingId.uuidString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Summaries
    
    func fetchSummary(recordingId: UUID) async throws -> Summary? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [Summary] = try await client
            .from("summaries")
            .select()
            .eq("recording_id", value: recordingId.uuidString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Processing Pipeline Methods
    
    /// Fetch a single recording by ID
    func fetchRecording(id: UUID) async throws -> Recording? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    /// Fetch recordings that are still being processed
    func fetchPendingRecordings() async throws -> [Recording] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .in("status", values: ["processing", "transcribing", "summarizing"])
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    /// Update the status of a recording
    func updateRecordingStatus(
        id: UUID,
        status: RecordingStatus,
        errorMessage: String? = nil
    ) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        var updates: [String: String?] = ["status": status.rawValue]
        if let errorMessage = errorMessage {
            updates["error_message"] = errorMessage
        }
        
        try await client
            .from("recordings")
            .update(updates)
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Increment the retry count for a recording
    func incrementRetryCount(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Fetch current retry count and increment
        if let recording = try await fetchRecording(id: id) {
            let newCount = recording.retryCount + 1
            try await client
                .from("recordings")
                .update(["retry_count": newCount])
                .eq("id", value: id.uuidString)
                .execute()
        }
    }
    
    /// Reset retry count (for manual retry)
    func resetRetryCount(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("recordings")
            .update(["retry_count": 0])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    /// Fetch speakers for a recording
    func fetchRecordingSpeakers(recordingId: UUID) async throws -> [RecordingSpeaker] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [RecordingSpeaker] = try await client
            .from("recording_speakers")
            .select()
            .eq("recording_id", value: recordingId.uuidString)
            .order("speaker_number", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    /// Fetch recording type by ID
    func fetchRecordingType(id: UUID) async throws -> RecordingType? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [RecordingType] = try await client
            .from("recording_types")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    // MARK: - Create Transcript & Summary
    
    /// Create a new transcript
    func createTranscript(_ transcript: Transcript) async throws -> Transcript {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Transcript] = try await client
            .from("transcripts")
            .insert(transcript)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    /// Create a new summary
    func createSummary(_ summary: Summary) async throws -> Summary {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Summary] = try await client
            .from("summaries")
            .insert(summary)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    /// Fetch failed recordings for "Needs Attention" view
    func fetchFailedRecordings() async throws -> [Recording] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [Recording] = try await client
            .from("recordings")
            .select()
            .eq("status", value: "failed")
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return response
    }
}

