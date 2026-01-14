// DailySummary.swift
// Auto-generated nightly summary

import Foundation

struct DailySummary: Identifiable, Codable {
    let id: UUID
    var date: Date
    var summaryText: String
    var recordingCount: Int
    // embedding is Vector(1536) - handled separately for pgvector
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case date
        case summaryText = "summary_text"
        case recordingCount = "recording_count"
        case createdAt = "created_at"
    }
    
    // Custom decoder to handle date stored as "yyyy-MM-dd" string
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.id = try container.decode(UUID.self, forKey: .id)
        self.summaryText = try container.decode(String.self, forKey: .summaryText)
        self.recordingCount = try container.decode(Int.self, forKey: .recordingCount)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Handle date as string "yyyy-MM-dd"
        let dateString = try container.decode(String.self, forKey: .date)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        
        if let parsedDate = formatter.date(from: dateString) {
            self.date = parsedDate
        } else {
            throw DecodingError.dataCorruptedError(
                forKey: .date,
                in: container,
                debugDescription: "Cannot decode date from: \(dateString)"
            )
        }
    }
    
    // Standard init for creating new summaries
    init(id: UUID, date: Date, summaryText: String, recordingCount: Int, createdAt: Date) {
        self.id = id
        self.date = date
        self.summaryText = summaryText
        self.recordingCount = recordingCount
        self.createdAt = createdAt
    }
}
