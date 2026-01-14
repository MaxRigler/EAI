// SummarizationService.swift
// Claude API integration for summarization and task extraction

import Foundation

/// Service for generating summaries and extracting tasks using Claude API
class SummarizationService {
    static let shared = SummarizationService()
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generate a summary from a transcript using the recording type's prompt template
    func summarize(
        transcript: Transcript,
        recordingType: RecordingType,
        context: String?
    ) async throws -> SummarizationResult {
        guard let apiKey = KeychainManager.shared.claudeAPIKey else {
            throw SummarizationError.missingAPIKey
        }
        
        // Build the system prompt from the recording type template
        var systemPrompt = recordingType.promptTemplate
        
        // Append context if provided
        if let context = context, !context.isEmpty {
            systemPrompt += "\n\nAdditional context provided by the user:\n\(context)"
        }
        
        // Format transcript with speaker segments
        let formattedTranscript = formatTranscript(transcript)
        
        let userMessage = """
        Please analyze the following transcript and provide a structured summary:
        
        \(formattedTranscript)
        """
        
        let response = try await callClaudeAPI(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            userMessage: userMessage
        )
        
        return SummarizationResult(
            summaryText: response,
            promptTemplateUsed: recordingType.promptTemplate
        )
    }
    
    /// Extract tasks from a transcript
    func extractTasks(
        transcript: Transcript,
        speakerContactMap: [Int: UUID]  // Maps speaker number to contact ID
    ) async throws -> [ExtractedTask] {
        guard let apiKey = KeychainManager.shared.claudeAPIKey else {
            throw SummarizationError.missingAPIKey
        }
        
        let systemPrompt = """
        You are analyzing a conversation transcript to extract action items and tasks.
        
        Review the transcript and identify any commitments, promises, or tasks mentioned, including:
        - Things someone said they would do ("I'll send you...", "Let me get back to you on...")
        - Requests made ("Can you send me...", "Please follow up on...")
        - Scheduled follow-ups ("Let's talk next week", "I'll call you Tuesday")
        - Information to research or find
        - People to contact or introduce
        
        For each task, provide:
        1. Description: Clear, actionable task description
        2. Owner: Who should do this (use speaker number)
        3. Due Date: If mentioned in ISO format (YYYY-MM-DD), otherwise null
        4. Priority: Based on urgency signals (high/medium/low)
        5. Source Quote: Brief quote from transcript where this was mentioned
        
        Return ONLY a JSON array with no additional text:
        [
          {
            "description": "Send product demo deck",
            "owner_speaker": 1,
            "due_date": "2024-01-15",
            "priority": "high",
            "source_quote": "I'll get you that demo deck by Monday"
          }
        ]
        
        If no tasks are found, return an empty array: []
        Only include genuine action items. Do not invent tasks that weren't discussed.
        """
        
        let formattedTranscript = formatTranscript(transcript)
        
        let userMessage = """
        Extract all action items and tasks from this transcript:
        
        \(formattedTranscript)
        """
        
        let response = try await callClaudeAPI(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            userMessage: userMessage
        )
        
        // Parse the JSON response
        return try parseTasksResponse(response, speakerContactMap: speakerContactMap)
    }
    
    // MARK: - Private Helpers
    
    private func formatTranscript(_ transcript: Transcript) -> String {
        if transcript.speakerSegments.isEmpty {
            return transcript.fullText
        }
        
        return transcript.speakerSegments.map { segment in
            "[Speaker \(segment.speaker) @ \(segment.formattedTimestamp)] \(segment.text)"
        }.joined(separator: "\n\n")
    }
    
    private func callClaudeAPI(
        apiKey: String,
        systemPrompt: String,
        userMessage: String
    ) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SummarizationError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SummarizationError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw SummarizationError.invalidResponse
        }
        
        return text
    }
    
    private func parseTasksResponse(
        _ response: String,
        speakerContactMap: [Int: UUID]
    ) throws -> [ExtractedTask] {
        // Clean the response - sometimes Claude adds markdown code blocks
        var cleanedResponse = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleanedResponse.hasPrefix("```json") {
            cleanedResponse = String(cleanedResponse.dropFirst(7))
        } else if cleanedResponse.hasPrefix("```") {
            cleanedResponse = String(cleanedResponse.dropFirst(3))
        }
        if cleanedResponse.hasSuffix("```") {
            cleanedResponse = String(cleanedResponse.dropLast(3))
        }
        cleanedResponse = cleanedResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let data = cleanedResponse.data(using: .utf8) else {
            throw SummarizationError.taskParsingFailed
        }
        
        let decoder = JSONDecoder()
        let rawTasks = try decoder.decode([RawExtractedTask].self, from: data)
        
        return rawTasks.map { raw in
            let contactId = speakerContactMap[raw.ownerSpeaker]
            let dueDate: Date? = raw.dueDate.flatMap { dateString in
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter.date(from: dateString)
            }
            
            return ExtractedTask(
                description: raw.description,
                contactId: contactId,
                dueDate: dueDate,
                priority: raw.priority,
                sourceQuote: raw.sourceQuote
            )
        }
    }
}

// MARK: - Supporting Types

struct SummarizationResult {
    let summaryText: String
    let promptTemplateUsed: String
}

struct ExtractedTask {
    let description: String
    let contactId: UUID?
    let dueDate: Date?
    let priority: String
    let sourceQuote: String
}

private struct RawExtractedTask: Codable {
    let description: String
    let ownerSpeaker: Int
    let dueDate: String?
    let priority: String
    let sourceQuote: String
    
    enum CodingKeys: String, CodingKey {
        case description
        case ownerSpeaker = "owner_speaker"
        case dueDate = "due_date"
        case priority
        case sourceQuote = "source_quote"
    }
}

// MARK: - Errors

enum SummarizationError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case taskParsingFailed
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let statusCode, let message):
            return "Claude API error (\(statusCode)): \(message)"
        case .taskParsingFailed:
            return "Failed to parse extracted tasks"
        }
    }
}
