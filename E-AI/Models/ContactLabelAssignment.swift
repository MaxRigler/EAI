// ContactLabelAssignment.swift
// Junction model for contact-label assignments

import Foundation

struct ContactLabelAssignment: Identifiable, Codable {
    let id: UUID
    let labelId: UUID
    let contactId: UUID
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case labelId = "label_id"
        case contactId = "contact_id"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        labelId: UUID,
        contactId: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.labelId = labelId
        self.contactId = contactId
        self.createdAt = createdAt
    }
}
