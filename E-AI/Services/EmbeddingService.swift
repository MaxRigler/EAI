// EmbeddingService.swift
// OpenAI API integration for generating vector embeddings

import Foundation

/// Service for generating text embeddings using OpenAI's API
/// Embeddings are stored in pgvector columns for semantic search
class EmbeddingService {
    static let shared = EmbeddingService()
    
    private let baseURL = "https://api.openai.com/v1/embeddings"
    private let model = "text-embedding-3-small"  // 1536 dimensions
    
    private init() {}
    
    // MARK: - Public API
    
    /// Generate an embedding vector for the given text
    /// - Parameter text: Text to embed (will be truncated if too long)
    /// - Returns: Array of 1536 floats representing the embedding
    func generateEmbedding(for text: String) async throws -> [Float] {
        guard let apiKey = KeychainManager.shared.openaiAPIKey else {
            throw EmbeddingError.missingAPIKey
        }
        
        // Truncate text if too long (max ~8000 tokens for this model)
        let truncatedText = truncateText(text, maxCharacters: 30000)
        
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": model,
            "input": truncatedText
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EmbeddingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw EmbeddingError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]],
              let firstData = dataArray.first,
              let embedding = firstData["embedding"] as? [Double] else {
            throw EmbeddingError.invalidResponse
        }
        
        // Convert to Float array (pgvector uses float4)
        return embedding.map { Float($0) }
    }
    
    /// Update the embedding column for a transcript
    func updateTranscriptEmbedding(transcriptId: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw EmbeddingError.databaseNotInitialized
        }
        
        // Convert embedding to pgvector format: '[0.1,0.2,0.3,...]'
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        // Use RPC call to update the embedding (since we need to cast to vector type)
        try await client.rpc(
            "update_transcript_embedding",
            params: [
                "p_transcript_id": transcriptId.uuidString,
                "p_embedding": vectorString
            ]
        ).execute()
        
        print("EmbeddingService: Updated transcript embedding for \(transcriptId)")
    }
    
    /// Update the embedding column for a summary
    func updateSummaryEmbedding(summaryId: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw EmbeddingError.databaseNotInitialized
        }
        
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        try await client.rpc(
            "update_summary_embedding",
            params: [
                "p_summary_id": summaryId.uuidString,
                "p_embedding": vectorString
            ]
        ).execute()
        
        print("EmbeddingService: Updated summary embedding for \(summaryId)")
    }
    
    /// Update the embedding column for a daily summary
    func updateDailySummaryEmbedding(dailySummaryId: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw EmbeddingError.databaseNotInitialized
        }
        
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        try await client.rpc(
            "update_daily_summary_embedding",
            params: [
                "p_daily_summary_id": dailySummaryId.uuidString,
                "p_embedding": vectorString
            ]
        ).execute()
        
        print("EmbeddingService: Updated daily summary embedding for \(dailySummaryId)")
    }
    
    // MARK: - Private Helpers
    
    private func truncateText(_ text: String, maxCharacters: Int) -> String {
        if text.count <= maxCharacters {
            return text
        }
        return String(text.prefix(maxCharacters))
    }
    
    private func formatEmbeddingForPgvector(_ embedding: [Float]) -> String {
        let values = embedding.map { String(format: "%.8f", $0) }.joined(separator: ",")
        return "[\(values)]"
    }
}

// MARK: - SQL Functions for Embedding Updates
// Run these in Supabase SQL Editor to create the RPC functions

/*
-- Function to update transcript embedding
CREATE OR REPLACE FUNCTION update_transcript_embedding(
    p_transcript_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE transcripts
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_transcript_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update summary embedding
CREATE OR REPLACE FUNCTION update_summary_embedding(
    p_summary_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE summaries
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_summary_id;
END;
$$ LANGUAGE plpgsql;

-- Function to update daily summary embedding
CREATE OR REPLACE FUNCTION update_daily_summary_embedding(
    p_daily_summary_id UUID,
    p_embedding TEXT
)
RETURNS VOID AS $$
BEGIN
    UPDATE daily_summaries
    SET embedding = p_embedding::vector(1536)
    WHERE id = p_daily_summary_id;
END;
$$ LANGUAGE plpgsql;
*/

// MARK: - Errors

enum EmbeddingError: LocalizedError {
    case missingAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case databaseNotInitialized
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key not configured. Please add it in Settings."
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let message):
            return "OpenAI API error (\(statusCode)): \(message)"
        case .databaseNotInitialized:
            return "Database not initialized"
        }
    }
}
