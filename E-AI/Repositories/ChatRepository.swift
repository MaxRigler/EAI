// ChatRepository.swift
// CRUD for chat threads and messages

import Foundation

class ChatRepository {
    
    // MARK: - Threads
    
    func fetchAllThreads() async throws -> [ChatThread] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [ChatThread] = try await client
            .from("chat_threads")
            .select()
            .order("updated_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func createThread(_ thread: ChatThread) async throws -> ChatThread {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [ChatThread] = try await client
            .from("chat_threads")
            .insert(thread)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    func deleteThread(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("chat_threads")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    // MARK: - Messages
    
    func fetchMessages(threadId: UUID) async throws -> [ChatMessage] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [ChatMessage] = try await client
            .from("chat_messages")
            .select()
            .eq("thread_id", value: threadId.uuidString)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func createMessage(_ message: ChatMessage) async throws -> ChatMessage {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [ChatMessage] = try await client
            .from("chat_messages")
            .insert(message)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    // MARK: - Thread Updates
    
    func updateThreadTitle(id: UUID, title: String) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("chat_threads")
            .update(["title": title])
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func updateThreadTimestamp(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("chat_threads")
            .update(["updated_at": ISO8601DateFormatter().string(from: Date())])
            .eq("id", value: id.uuidString)
            .execute()
    }
}
