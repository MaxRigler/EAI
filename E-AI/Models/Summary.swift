// Summary.swift
// AI-generated summary of a recording

import Foundation

struct Summary: Identifiable, Codable {
    let id: UUID
    var recordingId: UUID
    var summaryText: String
    var promptTemplateUsed: String?
    // embedding is Vector(1536) - handled separately for pgvector
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordingId = "recording_id"
        case summaryText = "summary_text"
        case promptTemplateUsed = "prompt_template_used"
        case createdAt = "created_at"
    }
}
