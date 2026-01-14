// TaskRepository.swift
// CRUD for tasks

import Foundation

class TaskRepository {
    
    // MARK: - Response Types for Joins
    
    /// Nested response for joined recording with recording type
    private struct RecordingJoinResponse: Codable {
        let createdAt: Date
        let recordingTypeId: UUID?
        let recordingTypes: RecordingTypeResponse?
        
        enum CodingKeys: String, CodingKey {
            case createdAt = "created_at"
            case recordingTypeId = "recording_type_id"
            case recordingTypes = "recording_types"
        }
    }
    
    private struct RecordingTypeResponse: Codable {
        let name: String
    }
    
    /// Response struct to decode joined task query
    private struct TaskJoinResponse: Codable {
        let id: UUID
        let contactId: UUID?
        let recordingId: UUID?
        let description: String
        let status: TaskStatus
        let dueDate: Date?
        let createdAt: Date
        let completedAt: Date?
        let crmContacts: CRMContact?
        let recordings: RecordingJoinResponse?
        
        enum CodingKeys: String, CodingKey {
            case id
            case contactId = "contact_id"
            case recordingId = "recording_id"
            case description
            case status
            case dueDate = "due_date"
            case createdAt = "created_at"
            case completedAt = "completed_at"
            case crmContacts = "crm_contacts"
            case recordings
        }
        
        func toAppTask() -> AppTask {
            var task = AppTask(
                id: id,
                contactId: contactId,
                recordingId: recordingId,
                description: description,
                status: status,
                dueDate: dueDate,
                createdAt: createdAt,
                completedAt: completedAt
            )
            
            // Populate transient properties
            task.contact = crmContacts
            task.contactName = crmContacts?.name
            task.recordingTime = recordings?.createdAt
            task.recordingTypeName = recordings?.recordingTypes?.name
            
            return task
        }
    }
    
    // MARK: - Fetch Methods
    
    func fetchAllTasks() async throws -> [AppTask] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        // Select tasks with joined contact and recording data
        let response: [TaskJoinResponse] = try await client
            .from("tasks")
            .select("""
                *,
                crm_contacts(id, name, email, phone, business_type, company, domain, deal_stage, tags, custom_fields, is_company, company_id, created_at, updated_at, apple_contact_id),
                recordings(created_at, recording_type_id, recording_types(name))
            """)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { $0.toAppTask() }
    }
    
    func fetchOpenTasks() async throws -> [AppTask] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        let response: [AppTask] = try await client
            .from("tasks")
            .select()
            .eq("is_completed", value: false)
            .order("due_date", ascending: true)
            .execute()
            .value
        
        return response
    }
    
    func fetchTasks(contactId: UUID) async throws -> [AppTask] {
        guard let client = await SupabaseManager.shared.getClient() else {
            return []
        }
        
        // Use the same join pattern as fetchAllTasks to get recording context
        let response: [TaskJoinResponse] = try await client
            .from("tasks")
            .select("""
                *,
                crm_contacts(id, name, email, phone, business_type, company, domain, deal_stage, tags, custom_fields, is_company, company_id, created_at, updated_at, apple_contact_id),
                recordings(created_at, recording_type_id, recording_types(name))
            """)
            .eq("contact_id", value: contactId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response.map { $0.toAppTask() }
    }
    
    func createTask(_ task: AppTask) async throws -> AppTask {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [AppTask] = try await client
            .from("tasks")
            .insert(task)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        return created
    }
    
    func updateTask(_ task: AppTask) async throws -> AppTask {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [AppTask] = try await client
            .from("tasks")
            .update(task)
            .eq("id", value: task.id.uuidString)
            .select()
            .execute()
            .value
        
        guard let updated = response.first else {
            throw RepositoryError.updateFailed
        }
        
        return updated
    }
    
    func toggleTaskCompletion(_ task: AppTask) async throws -> AppTask {
        var updated = task
        if updated.status == .completed {
            updated.status = .open
            updated.completedAt = nil
        } else {
            updated.status = .completed
            updated.completedAt = Date()
        }
        return try await updateTask(updated)
    }
    
    func deleteTask(id: UUID) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        print("TaskRepository: ⚠️ DELETE task requested - ID: \(id)")
        
        try await client
            .from("tasks")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
        
        print("TaskRepository: ✅ Successfully deleted task: \(id)")
    }
}
