// DailySummaryService.swift
// Service for generating AI-powered daily summaries using Claude API

import Foundation

/// Service for generating daily summaries of all recordings
class DailySummaryService {
    static let shared = DailySummaryService()
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    
    private let recordingRepository = RecordingRepository()
    private let dailyRepository = DailyRepository()
    
    private init() {}
    
    // MARK: - Daily Summary Prompt
    
    private let dailySummaryPrompt = """
    You are generating a daily summary for a sales/business professional at Equity Advance.

    You will receive summaries of all calls/meetings from today.

    Generate a concise daily brief with:

    ## Today at a Glance
    - Total calls/meetings
    - Key wins or positive developments
    - Issues or concerns that arose

    ## Highlights
    Top 3-5 most important interactions and why they matter.

    ## Hot Leads / Opportunities
    Anyone showing strong interest or ready to move forward.

    ## Requires Attention
    - Urgent follow-ups needed
    - Problems to address
    - Time-sensitive commitments

    ## Tomorrow's Priorities
    Based on today's calls, what should be the focus tomorrow?

    ## Open Tasks Created Today
    List of new action items from today's interactions.

    Keep it scannable - this should take 60 seconds to read and give a complete picture of the day.
    """
    
    // MARK: - Public API
    
    /// Generate a daily summary for the specified date
    /// - Parameter date: The date to generate summary for
    /// - Returns: The generated DailySummary
    func generateDailySummary(for date: Date) async throws -> DailySummary {
        print("DailySummaryService: Starting summary generation for \(date)")
        
        // 1. Fetch all recordings from the day
        let recordings = try await recordingRepository.fetchRecordings(for: date)
        print("DailySummaryService: Found \(recordings.count) recordings")
        
        // If no recordings, create a simple "no activity" summary
        if recordings.isEmpty {
            return try await saveEmptySummary(for: date)
        }
        
        // 2. Fetch summaries for each completed recording
        var recordingSummaries: [(recording: Recording, summary: String)] = []
        
        for recording in recordings {
            if recording.status == .complete {
                if let summary = try? await recordingRepository.fetchSummary(recordingId: recording.id) {
                    // Also fetch contact names for context
                    var contactNames: [String] = []
                    if let speakers = try? await recordingRepository.fetchRecordingSpeakers(recordingId: recording.id) {
                        for speaker in speakers {
                            if let contactId = speaker.contactId,
                               let contact = try? await fetchContact(id: contactId) {
                                contactNames.append(contact.name)
                            }
                        }
                    }
                    
                    // Get recording type name
                    var typeName = "Recording"
                    if let typeId = recording.recordingTypeId,
                       let recordingType = try? await fetchRecordingType(id: typeId) {
                        typeName = recordingType.name
                    }
                    
                    var enrichedRecording = recording
                    enrichedRecording.recordingTypeName = typeName
                    enrichedRecording.contactNames = contactNames
                    
                    recordingSummaries.append((enrichedRecording, summary.summaryText))
                }
            }
        }
        
        print("DailySummaryService: Collected \(recordingSummaries.count) summaries")
        
        // If no completed recordings with summaries, create empty summary
        if recordingSummaries.isEmpty {
            return try await saveEmptySummary(for: date)
        }
        
        // 3. Build context for Claude
        let context = buildDailyContext(recordingSummaries: recordingSummaries, date: date)
        
        // 4. Call Claude API
        let summaryText = try await callClaudeAPI(context: context)
        print("DailySummaryService: Generated summary (\(summaryText.count) chars)")
        
        // 5. Save to database
        let dailySummary = try await saveDailySummary(
            date: date,
            summaryText: summaryText,
            recordingCount: recordingSummaries.count
        )
        
        // 6. Generate embedding (async, don't block)
        Task {
            await generateEmbedding(for: dailySummary)
        }
        
        return dailySummary
    }
    
    // MARK: - Private Helpers
    
    private func buildDailyContext(
        recordingSummaries: [(recording: Recording, summary: String)],
        date: Date
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        
        var context = """
        Date: \(dateFormatter.string(from: date))
        Total Recordings: \(recordingSummaries.count)
        
        === CALL/MEETING SUMMARIES ===
        
        """
        
        for (index, item) in recordingSummaries.enumerated() {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            
            let contactsStr = item.recording.contactNames.isEmpty 
                ? "Unknown Contact" 
                : item.recording.contactNames.joined(separator: ", ")
            
            context += """
            
            --- Recording \(index + 1) ---
            Type: \(item.recording.recordingTypeName ?? "General")
            Time: \(timeFormatter.string(from: item.recording.createdAt))
            Contacts: \(contactsStr)
            Duration: \(item.recording.formattedDuration)
            
            Summary:
            \(item.summary)
            
            """
        }
        
        return context
    }
    
    private func callClaudeAPI(context: String) async throws -> String {
        guard let apiKey = KeychainManager.shared.claudeAPIKey else {
            throw DailySummaryError.missingAPIKey
        }
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": dailySummaryPrompt,
            "messages": [
                ["role": "user", "content": "Please generate a daily summary based on the following recordings:\n\n\(context)"]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DailySummaryError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw DailySummaryError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw DailySummaryError.invalidResponse
        }
        
        return text
    }
    
    private func saveEmptySummary(for date: Date) async throws -> DailySummary {
        let summaryText = """
        ## Today at a Glance
        - No calls or meetings recorded today
        
        ## Tomorrow's Priorities
        - Start recording your calls and meetings to get AI-powered insights!
        """
        
        return try await saveDailySummary(
            date: date,
            summaryText: summaryText,
            recordingCount: 0
        )
    }
    
    private func saveDailySummary(
        date: Date,
        summaryText: String,
        recordingCount: Int
    ) async throws -> DailySummary {
        // Check if summary already exists for this date
        if let existing = try await dailyRepository.fetchDailySummary(for: date) {
            // Update existing
            var updated = existing
            updated.summaryText = summaryText
            updated.recordingCount = recordingCount
            return try await dailyRepository.updateDailySummary(updated)
        } else {
            // Create new
            let summary = DailySummary(
                id: UUID(),
                date: date,
                summaryText: summaryText,
                recordingCount: recordingCount,
                createdAt: Date()
            )
            return try await dailyRepository.saveDailySummary(summary)
        }
    }
    
    private func generateEmbedding(for summary: DailySummary) async {
        do {
            let embedding = try await EmbeddingService.shared.generateEmbedding(for: summary.summaryText)
            try await dailyRepository.updateDailySummaryEmbedding(id: summary.id, embedding: embedding)
            print("DailySummaryService: Embedding generated for daily summary \(summary.id)")
        } catch {
            print("DailySummaryService: Failed to generate embedding: \(error)")
        }
    }
    
    private func fetchContact(id: UUID) async throws -> CRMContact? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let response: [CRMContact] = try await client
            .from("crm_contacts")
            .select()
            .eq("id", value: id.uuidString.lowercased())
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    private func fetchRecordingType(id: UUID) async throws -> RecordingType? {
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
}

// MARK: - Errors

enum DailySummaryError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let statusCode, let message):
            return "Claude API error (\(statusCode)): \(message)"
        case .saveFailed:
            return "Failed to save daily summary"
        }
    }
}
