// Transcript.swift
// Full transcription with speaker segments

import Foundation

struct Transcript: Identifiable, Codable {
    let id: UUID
    var recordingId: UUID
    var fullText: String
    var speakerSegments: [SpeakerSegment]
    // embedding is Vector(1536) - handled separately for pgvector
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordingId = "recording_id"
        case fullText = "full_text"
        case speakerSegments = "speaker_segments"
        case createdAt = "created_at"
    }
}

struct SpeakerSegment: Codable, Identifiable {
    var id: String { "\(speaker)-\(start)" }
    
    let speaker: Int
    let start: Double
    let end: Double
    let text: String
    
    var formattedTimestamp: String {
        let minutes = Int(start) / 60
        let seconds = Int(start) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
