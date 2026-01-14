// Comment.swift
// Manual notes on contacts

import Foundation

struct Comment: Identifiable, Codable {
    let id: UUID
    var contactId: UUID
    var content: String
    let createdAt: Date
    var updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
