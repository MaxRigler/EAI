// Email.swift
// Email model for Gmail integration

import Foundation

struct Email: Codable, Identifiable {
    let id: UUID
    let contactId: UUID?
    let gmailId: String
    let threadId: String?
    let subject: String?
    let body: String?
    let direction: EmailDirection
    let timestamp: Date
    let createdAt: Date
    var isArchived: Bool
    var reminderDate: Date?
    
    // Additional fields for display
    var senderEmail: String?
    var senderName: String?
    var recipientEmail: String?
    
    enum EmailDirection: String, Codable {
        case inbound
        case outbound
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case gmailId = "gmail_id"
        case threadId = "thread_id"
        case subject
        case body
        case direction
        case timestamp
        case createdAt = "created_at"
        case isArchived = "is_archived"
        case reminderDate = "reminder_date"
        case senderEmail = "sender_email"
        case senderName = "sender_name"
        case recipientEmail = "recipient_email"
    }
    
    init(id: UUID = UUID(),
         contactId: UUID?,
         gmailId: String,
         threadId: String? = nil,
         subject: String?,
         body: String?,
         direction: EmailDirection,
         timestamp: Date,
         createdAt: Date = Date(),
         isArchived: Bool = false,
         reminderDate: Date? = nil,
         senderEmail: String? = nil,
         senderName: String? = nil,
         recipientEmail: String? = nil) {
        self.id = id
        self.contactId = contactId
        self.gmailId = gmailId
        self.threadId = threadId
        self.subject = subject
        self.body = body
        self.direction = direction
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.isArchived = isArchived
        self.reminderDate = reminderDate
        self.senderEmail = senderEmail
        self.senderName = senderName
        self.recipientEmail = recipientEmail
    }
}

// MARK: - Timeline Conversion

extension Email {
    func toTimelineItem() -> TimelineItem {
        let title: String
        if direction == .inbound {
            title = "Email from \(senderName ?? senderEmail ?? "Unknown")"
        } else {
            title = "Email to \(recipientEmail ?? "Unknown")"
        }
        
        let content = """
        **Subject:** \(subject ?? "(No Subject)")
        
        \(body ?? "")
        """
        
        return TimelineItem(
            id: id,
            type: .email,
            title: title,
            content: content,
            date: timestamp,
            sourceId: id
        )
    }
}
