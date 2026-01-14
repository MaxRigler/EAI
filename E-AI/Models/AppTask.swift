// AppTask.swift
// Task model (named AppTask to avoid collision with Swift's Task)

import Foundation

struct AppTask: Identifiable, Codable {
    let id: UUID
    var contactId: UUID?
    var recordingId: UUID?
    var description: String
    var status: TaskStatus
    var dueDate: Date?
    let createdAt: Date
    var completedAt: Date?
    
    // Transient properties for UI (not stored in DB)
    var contactName: String?
    var contact: CRMContact?       // Primary contact for navigation
    var contacts: [CRMContact] = [] // All contacts from the recording (for display)
    var recordingTypeName: String? // e.g. "Cold Call", "Client Support"
    var recordingTime: Date?       // When the call occurred
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case recordingId = "recording_id"
        case description
        case status
        case dueDate = "due_date"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
    
    init(
        id: UUID = UUID(),
        contactId: UUID? = nil,
        recordingId: UUID? = nil,
        description: String,
        status: TaskStatus = .open,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.contactId = contactId
        self.recordingId = recordingId
        self.description = description
        self.status = status
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum TaskStatus: String, Codable {
    case open
    case completed
}
