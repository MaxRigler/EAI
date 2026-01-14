// IMessageRepository.swift
// CRUD operations for iMessage chunks in Supabase

import Foundation

class IMessageRepository {
    
    // MARK: - Fetch Chunks
    
    /// Fetch all iMessage chunks for a contact
    func fetchChunks(contactId: UUID) async throws -> [IMessageChunk] {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [IMessageChunk] = try await client
            .from("imessage_chunks")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("date", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    /// Fetch a specific chunk by contact and date
    func fetchChunk(contactId: UUID, date: Date) async throws -> IMessageChunk? {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        
        let response: [IMessageChunk] = try await client
            .from("imessage_chunks")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .eq("date", value: dateString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    /// Fetch existing message GUIDs for a contact on a specific date
    func fetchExistingGuids(contactId: UUID, date: Date) async throws -> [String] {
        guard let chunk = try await fetchChunk(contactId: contactId, date: date) else {
            return []
        }
        return chunk.messageGuids
    }
    
    // MARK: - Create/Update Chunks
    
    /// Create a new iMessage chunk
    func createChunk(_ chunk: IMessageChunk) async throws -> IMessageChunk {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Create payload without embedding (handled separately)
        let payload = ChunkInsertPayload(
            id: chunk.id,
            contactId: chunk.contactId,
            date: chunk.date,
            content: chunk.content,
            messageCount: chunk.messageCount,
            messageGuids: chunk.messageGuids,
            rawMessages: chunk.rawMessages
        )
        
        let response: [IMessageChunk] = try await client
            .from("imessage_chunks")
            .insert(payload)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    /// Update an existing iMessage chunk
    func updateChunk(_ chunk: IMessageChunk) async throws -> IMessageChunk {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let payload = ChunkUpdatePayload(
            content: chunk.content,
            messageCount: chunk.messageCount,
            messageGuids: chunk.messageGuids,
            rawMessages: chunk.rawMessages
        )
        
        let response: [IMessageChunk] = try await client
            .from("imessage_chunks")
            .update(payload)
            .eq("id", value: chunk.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    /// Update chunk embedding using RPC function
    func updateChunkEmbedding(chunkId: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Format embedding for pgvector
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        try await client.rpc(
            "update_imessage_chunk_embedding",
            params: [
                "p_chunk_id": chunkId.uuidString,
                "p_embedding": vectorString
            ]
        ).execute()
        
        print("IMessageRepository: Updated embedding for chunk \(chunkId)")
    }
    
    // MARK: - Private Helpers
    
    private func formatEmbeddingForPgvector(_ embedding: [Float]) -> String {
        let values = embedding.map { String(format: "%.8f", $0) }.joined(separator: ",")
        return "[\(values)]"
    }
}

// MARK: - Payload Types

private struct ChunkInsertPayload: Encodable {
    let id: UUID
    let contactId: UUID
    let date: Date
    let content: String
    let messageCount: Int
    let messageGuids: [String]
    let rawMessages: [IMessageChunk.RawMessage]
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case date
        case content
        case messageCount = "message_count"
        case messageGuids = "message_guids"
        case rawMessages = "raw_messages"
    }
}

private struct ChunkUpdatePayload: Encodable {
    let content: String
    let messageCount: Int
    let messageGuids: [String]
    let rawMessages: [IMessageChunk.RawMessage]
    
    enum CodingKeys: String, CodingKey {
        case content
        case messageCount = "message_count"
        case messageGuids = "message_guids"
        case rawMessages = "raw_messages"
    }
}
