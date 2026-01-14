// ChatMessage.swift
// Individual message in a chat thread

import Foundation

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    var threadId: UUID
    var role: MessageRole
    var content: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case role
        case content
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        threadId: UUID,
        role: MessageRole,
        content: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.threadId = threadId
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
