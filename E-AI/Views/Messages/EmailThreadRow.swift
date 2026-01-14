// EmailThreadRow.swift
// Row component for displaying an email thread in the list

import SwiftUI

struct EmailThreadRow: View {
    let thread: EmailThread
    let isExpanded: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main thread row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Avatar/initials
                    avatar
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Top row: sender + timestamp
                        HStack {
                            Text(thread.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text(formattedTimestamp)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Subject line
                        HStack(spacing: 6) {
                            // Direction indicator
                            directionIndicator
                            
                            Text(thread.subject)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                        }
                        
                        // Snippet preview
                        Text(thread.snippet)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Expand indicator
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
            }
            .buttonStyle(.plain)
            
            // Expanded thread messages
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(thread.messages, id: \.id) { email in
                        EmailMessageRow(email: email)
                    }
                }
                .padding(.leading, 48)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Avatar
    
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Text(avatarInitials)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
        }
    }
    
    private var avatarInitials: String {
        let name = thread.displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
    
    // MARK: - Direction Indicator
    
    @ViewBuilder
    private var directionIndicator: some View {
        let direction = thread.latestMessage.direction
        
        HStack(spacing: 2) {
            Image(systemName: direction == .inbound ? "arrow.down.left" : "arrow.up.right")
                .font(.system(size: 8))
            Text(direction == .inbound ? "In" : "Out")
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(direction == .inbound ? .blue : .green)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            (direction == .inbound ? Color.blue : Color.green).opacity(0.15)
        )
        .cornerRadius(4)
    }
    
    // MARK: - Formatting
    
    private var formattedTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(thread.timestamp) {
            return thread.timestamp.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(thread.timestamp) {
            return "Yesterday"
        } else if calendar.isDate(thread.timestamp, equalTo: now, toGranularity: .weekOfYear) {
            return thread.timestamp.formatted(.dateTime.weekday(.abbreviated))
        } else {
            return thread.timestamp.formatted(date: .abbreviated, time: .omitted)
        }
    }
}

// MARK: - Email Message Row (for expanded view)

struct EmailMessageRow: View {
    let email: Email
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Direction badge
                directionBadge
                
                Text(email.direction == .inbound ? (email.senderName ?? email.senderEmail ?? "Unknown") : "You")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text(email.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Subject (if different from thread)
            if let subject = email.subject, !subject.isEmpty {
                Text(subject)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            // Body preview or full
            if let body = email.body {
                Text(body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(isExpanded ? nil : 3)
                
                if body.count > 150 {
                    Button(action: { isExpanded.toggle() }) {
                        Text(isExpanded ? "Show less" : "Show more")
                            .font(.caption2)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundColor(email.direction == .inbound ? .blue : .green)
                .opacity(0.5),
            alignment: .leading
        )
    }
    
    private var directionBadge: some View {
        Image(systemName: email.direction == .inbound ? "arrow.down.circle.fill" : "arrow.up.circle.fill")
            .font(.caption)
            .foregroundColor(email.direction == .inbound ? .blue : .green)
    }
}

#Preview {
    VStack {
        EmailThreadRow(
            thread: EmailThread(
                id: "1",
                subject: "Re: Project Update",
                participants: ["John Doe", "Jane Smith"],
                latestMessage: Email(
                    contactId: UUID(),
                    gmailId: "123",
                    threadId: "1",
                    subject: "Re: Project Update",
                    body: "Thanks for the update! Everything looks good.",
                    direction: .inbound,
                    timestamp: Date(),
                    senderEmail: "john@example.com",
                    senderName: "John Doe"
                ),
                messages: [],
                unreadCount: 0
            ),
            isExpanded: false,
            onTap: {}
        )
    }
    .padding()
    .frame(width: 380)
}
