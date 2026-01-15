// RAGSearchService.swift
// Retrieval-Augmented Generation for Chat queries

import Foundation

/// Service for RAG-powered chat responses
/// Combines vector search with Claude AI for contextual answers
class RAGSearchService {
    static let shared = RAGSearchService()
    
    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generate an AI response using RAG
    /// - Parameters:
    ///   - query: User's question
    ///   - conversationHistory: Previous messages in the thread for context
    /// - Returns: AI-generated response
    func generateResponse(
        query: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        print("RAGSearchService: 🔍 Starting query - '\(query.prefix(100))'")
        
        // Pre-check: OpenAI API key for embeddings
        guard KeychainManager.shared.openaiAPIKey != nil else {
            print("RAGSearchService: ❌ OpenAI API key not configured")
            throw RAGError.missingOpenAIKey
        }
        
        // Pre-check: Claude API key for responses
        guard KeychainManager.shared.claudeAPIKey != nil else {
            print("RAGSearchService: ❌ Claude API key not configured")
            throw RAGError.missingAPIKey
        }
        
        // 1. Generate embedding for the query
        print("RAGSearchService: 🧮 Generating query embedding...")
        let queryEmbedding: [Float]
        do {
            queryEmbedding = try await EmbeddingService.shared.generateEmbedding(for: query)
            print("RAGSearchService: ✅ Embedding generated (\(queryEmbedding.count) dimensions)")
        } catch {
            print("RAGSearchService: ❌ Embedding generation failed: \(error)")
            throw RAGError.embeddingFailed
        }
        
        // 2. Search for relevant content
        print("RAGSearchService: 🔎 Searching content with threshold 0.5...")
        let searchResults: [RAGSearchResult]
        do {
            searchResults = try await searchContent(embedding: queryEmbedding, limit: 10)
            print("RAGSearchService: ✅ Found \(searchResults.count) results")
            for (i, result) in searchResults.prefix(3).enumerated() {
                print("RAGSearchService:   [\(i+1)] \(result.contentType) - similarity: \(String(format: "%.3f", result.similarity)) - \(result.contactName ?? "no contact")")
            }
        } catch {
            print("RAGSearchService: ❌ Content search failed: \(error)")
            throw error
        }
        
        // 3. Build context from search results
        let context = buildContext(from: searchResults)
        
        // 4. Generate response with Claude
        print("RAGSearchService: 🤖 Calling Claude API...")
        let response = try await callClaude(
            query: query,
            context: context,
            conversationHistory: conversationHistory
        )
        print("RAGSearchService: ✅ Response generated (\(response.count) chars)")
        
        return response
    }
    
    // MARK: - Vector Search
    
    /// Search all content using vector similarity
    private func searchContent(embedding: [Float], limit: Int) async throws -> [RAGSearchResult] {
        guard let client = await SupabaseManager.shared.getClient() else {
            print("RAGSearchService: ❌ Database not initialized")
            throw RAGError.databaseNotInitialized
        }
        
        // Format embedding for pgvector
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        // Create params struct for RPC call
        // Using lower threshold (0.3) to catch more results for diagnostics
        let params = SearchParams(
            queryEmbedding: vectorString,
            matchThreshold: 0.3,
            matchCount: limit
        )
        
        // Call the search_all_content RPC function
        do {
            let response: [RAGSearchResultDTO] = try await client.rpc(
                "search_all_content",
                params: params
            ).execute().value
            
            print("RAGSearchService: 📊 RPC returned \(response.count) raw results")
            
            return response.map { dto in
                RAGSearchResult(
                    contentType: dto.contentType,
                    contentId: UUID(uuidString: dto.contentId) ?? UUID(),
                    contentText: dto.contentText,
                    contactId: dto.contactId.flatMap { UUID(uuidString: $0) },
                    contactName: dto.contactName,
                    similarity: dto.similarity
                )
            }
        } catch {
            print("RAGSearchService: ❌ RPC 'search_all_content' failed: \(error)")
            print("RAGSearchService: ⚠️  This may mean the function doesn't exist in Supabase")
            throw RAGError.searchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Context Building
    
    /// Build context string from search results
    private func buildContext(from results: [RAGSearchResult]) -> String {
        if results.isEmpty {
            print("RAGSearchService: ⚠️  No search results - providing diagnostic context to Claude")
            return """
            No relevant context found in the database.
            
            IMPORTANT DIAGNOSTIC INFO FOR YOUR RESPONSE:
            - The semantic search returned 0 results
            - This likely means recordings exist but don't have embeddings generated
            - Or the search query didn't match any stored content
            - Advise the user to check: (1) OpenAI API key in Settings, (2) that recordings have been fully processed
            """
        }
        
        var contextParts: [String] = []
        
        for (index, result) in results.prefix(5).enumerated() {
            let contactInfo = result.contactName.map { " (Contact: \($0))" } ?? ""
            let typeLabel: String
            switch result.contentType {
            case "transcript": typeLabel = "Call Transcript"
            case "summary": typeLabel = "Call Summary"
            case "email": typeLabel = "Email"
            case "imessage": typeLabel = "iMessage"
            case "daily_summary": typeLabel = "Daily Summary"
            default: typeLabel = result.contentType.capitalized
            }
            
            // Truncate long content
            let truncatedText = String(result.contentText.prefix(1500))
            
            contextParts.append("""
            --- \(typeLabel) #\(index + 1)\(contactInfo) (similarity: \(String(format: "%.2f", result.similarity))) ---
            \(truncatedText)
            """)
        }
        
        print("RAGSearchService: 📝 Built context with \(contextParts.count) items")
        return contextParts.joined(separator: "\n\n")
    }
    
    // MARK: - Claude API
    
    /// Call Claude API with RAG context
    private func callClaude(
        query: String,
        context: String,
        conversationHistory: [ChatMessage]
    ) async throws -> String {
        guard let apiKey = KeychainManager.shared.claudeAPIKey else {
            throw RAGError.missingAPIKey
        }
        
        let systemPrompt = """
        You are the user's AI-powered "Second Brain" assistant for their CRM system.
        
        You have access to their call transcripts, summaries, and notes from business conversations.
        Use this context to answer their questions accurately and helpfully.
        
        Guidelines:
        - Reference specific conversations, contacts, or details when relevant
        - If you don't have enough context to answer, say so honestly
        - Be concise but thorough
        - When mentioning contacts or calls, be specific about who/when if known
        - For follow-up suggestions, be actionable and specific
        
        CONTEXT FROM DATABASE:
        \(context)
        """
        
        // Build messages array including conversation history
        var messages: [[String: Any]] = []
        
        // Add recent conversation history (last 10 messages max)
        for message in conversationHistory.suffix(10) {
            messages.append([
                "role": message.role.rawValue,
                "content": message.content
            ])
        }
        
        // Add current query
        messages.append([
            "role": "user",
            "content": query
        ])
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let requestBody: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": systemPrompt,
            "messages": messages
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RAGError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw RAGError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw RAGError.invalidResponse
        }
        
        return text
    }
    
    // MARK: - Helpers
    
    private func formatEmbeddingForPgvector(_ embedding: [Float]) -> String {
        let values = embedding.map { String(format: "%.8f", $0) }.joined(separator: ",")
        return "[\(values)]"
    }
}

// MARK: - Data Types

/// Params for search_all_content RPC call
private struct SearchParams: Encodable, Sendable {
    let queryEmbedding: String
    let matchThreshold: Double
    let matchCount: Int
    
    enum CodingKeys: String, CodingKey {
        case queryEmbedding = "query_embedding"
        case matchThreshold = "match_threshold"
        case matchCount = "match_count"
    }
}

struct RAGSearchResult {
    let contentType: String
    let contentId: UUID
    let contentText: String
    let contactId: UUID?
    let contactName: String?
    let similarity: Float
}

/// DTO for Supabase RPC response
private struct RAGSearchResultDTO: Codable {
    let contentType: String
    let contentId: String
    let contentText: String
    let contactId: String?
    let contactName: String?
    let similarity: Float
    
    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case contentId = "content_id"
        case contentText = "content_text"
        case contactId = "contact_id"
        case contactName = "contact_name"
        case similarity
    }
}

// MARK: - Errors

enum RAGError: LocalizedError {
    case missingAPIKey
    case missingOpenAIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case databaseNotInitialized
    case embeddingFailed
    case searchFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Claude API key not configured. Please add it in Settings."
        case .missingOpenAIKey:
            return "OpenAI API key not configured. Please add it in Settings to enable semantic search."
        case .invalidResponse:
            return "Invalid response from Claude API"
        case .apiError(let statusCode, let message):
            return "Claude API error (\(statusCode)): \(message)"
        case .databaseNotInitialized:
            return "Database not initialized"
        case .embeddingFailed:
            return "Failed to generate query embedding. Check your OpenAI API key in Settings."
        case .searchFailed(let reason):
            return "Search failed: \(reason). The search_all_content function may not exist in Supabase."
        }
    }
}
