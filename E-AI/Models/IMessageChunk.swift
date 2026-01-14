// IMessageChunk.swift
// Model for iMessage daily conversation chunks

import Foundation

struct IMessageChunk: Identifiable, Codable {
    let id: UUID
    let contactId: UUID
    let date: Date
    var content: String
    var messageCount: Int
    var messageGuids: [String]
    var rawMessages: [RawMessage]
    var embedding: [Float]?
    let createdAt: Date
    var updatedAt: Date?
    
    struct RawMessage: Codable {
        let guid: String
        let text: String
        let direction: String  // "inbound" or "outbound"
        let timestamp: Date
        
        enum CodingKeys: String, CodingKey {
            case guid
            case text
            case direction
            case timestamp
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case date
        case content
        case messageCount = "message_count"
        case messageGuids = "message_guids"
        case rawMessages = "raw_messages"
        case embedding
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(
        id: UUID = UUID(),
        contactId: UUID,
        date: Date,
        content: String,
        messageCount: Int = 0,
        messageGuids: [String] = [],
        rawMessages: [RawMessage] = [],
        embedding: [Float]? = nil,
        createdAt: Date = Date(),
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.contactId = contactId
        self.date = date
        self.content = content
        self.messageCount = messageCount
        self.messageGuids = messageGuids
        self.rawMessages = rawMessages
        self.embedding = embedding
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - iMessage Record (from local database)

struct IMessageRecord {
    let guid: String
    let text: String
    let timestamp: Date
    let isFromMe: Bool
    
    var direction: String {
        isFromMe ? "outbound" : "inbound"
    }
}
