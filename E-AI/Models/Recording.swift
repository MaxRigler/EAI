// Recording.swift
// Audio recording metadata

import Foundation

struct Recording: Identifiable, Codable {
    let id: UUID
    var filePath: String
    var durationSeconds: Int?
    var recordingTypeId: UUID?
    var status: RecordingStatus
    var errorMessage: String?
    var retryCount: Int
    var context: String?  // Additional context for AI prompts
    let createdAt: Date
    var updatedAt: Date?
    
    // Transient properties (not stored in DB, used for UI)
    var recordingTypeName: String?
    var summaryPreview: String?
    var fullSummary: String?
    var contactNames: [String] = []
    var contacts: [CRMContact] = []  // Full contact objects for navigation
    
    enum CodingKeys: String, CodingKey {
        case id
        case filePath = "file_path"
        case durationSeconds = "duration_seconds"
        case recordingTypeId = "recording_type_id"
        case status
        case errorMessage = "error_message"
        case retryCount = "retry_count"
        case context
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var formattedDuration: String {
        guard let seconds = durationSeconds else { return "--:--" }
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
}

enum RecordingStatus: String, Codable {
    case processing
    case transcribing
    case summarizing
    case complete
    case failed
}

// MARK: - Recording Speaker

struct RecordingSpeaker: Identifiable, Codable {
    let id: UUID
    var recordingId: UUID
    var speakerNumber: Int
    var contactId: UUID?
    var isUser: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case recordingId = "recording_id"
        case speakerNumber = "speaker_number"
        case contactId = "contact_id"
        case isUser = "is_user"
    }
}
