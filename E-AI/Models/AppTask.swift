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
    
    // Custom decoder to handle date-only format for due_date (PostgreSQL DATE type returns "YYYY-MM-DD")
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        contactId = try container.decodeIfPresent(UUID.self, forKey: .contactId)
        recordingId = try container.decodeIfPresent(UUID.self, forKey: .recordingId)
        description = try container.decode(String.self, forKey: .description)
        status = try container.decode(TaskStatus.self, forKey: .status)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        
        // Handle due_date which can be either:
        // - null
        // - date-only string "YYYY-MM-DD" (from PostgreSQL DATE type)
        // - full ISO8601 timestamp (if stored differently)
        if let dueDateString = try container.decodeIfPresent(String.self, forKey: .dueDate) {
            // Try date-only format first (YYYY-MM-DD)
            let dateOnlyFormatter = DateFormatter()
            dateOnlyFormatter.dateFormat = "yyyy-MM-dd"
            dateOnlyFormatter.timeZone = TimeZone.current
            
            if let date = dateOnlyFormatter.date(from: dueDateString) {
                dueDate = date
            } else {
                // Fall back to ISO8601 parser
                let isoFormatter = ISO8601DateFormatter()
                isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = isoFormatter.date(from: dueDateString) {
                    dueDate = date
                } else {
                    // Try without fractional seconds
                    isoFormatter.formatOptions = [.withInternetDateTime]
                    dueDate = isoFormatter.date(from: dueDateString)
                }
            }
        } else {
            dueDate = nil
        }
    }
}

enum TaskStatus: String, Codable {
    case open
    case completed
}

