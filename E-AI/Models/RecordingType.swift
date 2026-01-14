// RecordingType.swift
// Recording categories with prompt templates

import Foundation

struct RecordingType: Identifiable, Codable {
    let id: UUID
    var name: String
    var promptTemplate: String
    var isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case promptTemplate = "prompt_template"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        name: String,
        promptTemplate: String,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.promptTemplate = promptTemplate
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
