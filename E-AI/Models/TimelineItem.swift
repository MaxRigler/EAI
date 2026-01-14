// TimelineItem.swift
// Unified timeline item for contact detail view

import Foundation
import SwiftUI

struct TimelineItem: Identifiable {
    let id: UUID
    let type: TimelineItemType
    let title: String
    let content: String
    let date: Date
    let sourceId: UUID?
    
    var icon: String {
        switch type {
        case .recording:
            return "mic.fill"
        case .comment:
            return "text.bubble.fill"
        case .task:
            return "checkmark.circle.fill"
        case .email:
            return "envelope.fill"
        case .message:
            return "message.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .recording:
            return .purple
        case .comment:
            return .blue
        case .task:
            return .green
        case .email:
            return .orange
        case .message:
            return .teal
        }
    }
}

enum TimelineItemType {
    case recording
    case comment
    case task
    case email
    case message
}
