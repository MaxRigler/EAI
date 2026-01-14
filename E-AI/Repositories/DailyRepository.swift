// DailyRepository.swift
// CRUD for daily summaries and recording types

import Foundation

class DailyRepository {
    
    // MARK: - Recording Types (main use case for now)
    
    func fetchRecordingTypes() async throws -> [RecordingType] {
        guard let client = await SupabaseManager.shared.getClient() else {
            print("DailyRepository: Supabase not initialized, returning empty")
            return []
        }
        
        let response: [RecordingType] = try await client
            .from("recording_types")
            .select()
            .eq("is_active", value: true)
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    func fetchAllRecordingTypes() async throws -> [RecordingType] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [RecordingType] = try await client
            .from("recording_types")
            .select()
            .order("name")
            .execute()
            .value
        
        return response
    }
    
    func createRecordingType(_ type: RecordingType) async throws -> RecordingType {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [RecordingType] = try await client
            .from("recording_types")
            .insert(type)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    func deleteRecordingType(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        struct ActiveUpdate: Codable {
            let isActive: Bool
            
            enum CodingKeys: String, CodingKey {
                case isActive = "is_active"
            }
        }
        
        try await client
            .from("recording_types")
            .update(ActiveUpdate(isActive: false))
            .eq("id", value: id.uuidString)
            .execute()
    }
    
    func updateRecordingType(_ type: RecordingType) async throws -> RecordingType {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        struct UpdatePayload: Codable {
            let name: String
            let promptTemplate: String
            let isActive: Bool
            
            enum CodingKeys: String, CodingKey {
                case name
                case promptTemplate = "prompt_template"
                case isActive = "is_active"
            }
        }
        
        let payload = UpdatePayload(
            name: type.name,
            promptTemplate: type.promptTemplate,
            isActive: type.isActive
        )
        
        let response: [RecordingType] = try await client
            .from("recording_types")
            .update(payload)
            .eq("id", value: type.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    // MARK: - Daily Summaries
    
    func fetchDailySummary(for date: Date) async throws -> DailySummary? {
        guard let client = await SupabaseManager.shared.getClient() else {
            return nil
        }
        
        let dateString = DateFormatter.yyyyMMdd.string(from: date)
        
        let response: [DailySummary] = try await client
            .from("daily_summaries")
            .select()
            .eq("date", value: dateString)
            .limit(1)
            .execute()
            .value
        
        return response.first
    }
    
    func saveDailySummary(_ summary: DailySummary) async throws -> DailySummary {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Convert date to string for storage
        let dateString = DateFormatter.yyyyMMdd.string(from: summary.date)
        
        struct InsertPayload: Codable {
            let id: UUID
            let date: String
            let summaryText: String
            let recordingCount: Int
            
            enum CodingKeys: String, CodingKey {
                case id, date
                case summaryText = "summary_text"
                case recordingCount = "recording_count"
            }
        }
        
        let payload = InsertPayload(
            id: summary.id,
            date: dateString,
            summaryText: summary.summaryText,
            recordingCount: summary.recordingCount
        )
        
        let response: [DailySummary] = try await client
            .from("daily_summaries")
            .insert(payload)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    func updateDailySummary(_ summary: DailySummary) async throws -> DailySummary {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        struct UpdatePayload: Codable {
            let summaryText: String
            let recordingCount: Int
            
            enum CodingKeys: String, CodingKey {
                case summaryText = "summary_text"
                case recordingCount = "recording_count"
            }
        }
        
        let payload = UpdatePayload(
            summaryText: summary.summaryText,
            recordingCount: summary.recordingCount
        )
        
        let response: [DailySummary] = try await client
            .from("daily_summaries")
            .update(payload)
            .eq("id", value: summary.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    func updateDailySummaryEmbedding(id: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Convert embedding to string format for pgvector
        let embeddingString = "[" + embedding.map { String($0) }.joined(separator: ",") + "]"
        
        // Use RPC function to update embedding
        try await client.rpc(
            "update_daily_summary_embedding",
            params: [
                "p_daily_summary_id": id.uuidString,
                "p_embedding": embeddingString
            ]
        ).execute()
    }
    
    // MARK: - Comments
    
    func fetchComments(contactId: UUID) async throws -> [Comment] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [Comment] = try await client
            .from("comments")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func createComment(_ comment: Comment) async throws -> Comment {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Comment] = try await client
            .from("comments")
            .insert(comment)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
}

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
