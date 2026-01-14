// TimelineEmailThreadRow.swift
// Row component for displaying an email thread in contact/company timelines
// Adapted from EmailThreadRow but without archive/snooze functionality

import SwiftUI

struct TimelineEmailThreadRow: View {
    let thread: TimelineEmailThread
    let isExpanded: Bool
    let onTap: () -> Void
    let onReply: ((String) async throws -> Void)?
    
    @State private var showReplyComposer = false
    @State private var replyText = ""
    @State private var isSending = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main thread row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Avatar/initials
                    avatar
                    
                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        // Top row: sender + message count + timestamp
                        HStack {
                            Text(thread.displayName)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            
                            // Message count badge
                            if thread.emails.count > 1 {
                                Text("\(thread.emails.count)")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.secondary)
                                    .clipShape(Capsule())
                            }
                            
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
                    ForEach(thread.emails, id: \.id) { email in
                        TimelineEmailMessageRow(email: email)
                    }
                    
                    // Reply section
                    replySection
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
        .alert("Error Sending Reply", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Reply Section
    
    @ViewBuilder
    private var replySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 8)
            
            // Reply button that opens sheet
            Button(action: { showReplyComposer = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 12))
                    Text("Reply")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundColor(.accentColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .sheet(isPresented: $showReplyComposer) {
            TimelineReplyComposerSheet(
                recipientName: thread.displayName,
                recipientEmail: thread.recipientEmail,
                subject: thread.subject,
                onSend: { text in
                    replyText = text
                    sendReply()
                },
                onCancel: {
                    showReplyComposer = false
                }
            )
        }
    }
    
    private var canSend: Bool {
        !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func sendReply() {
        guard canSend, let onReply = onReply else { return }
        
        isSending = true
        
        Task {
            do {
                try await onReply(replyText.trimmingCharacters(in: .whitespacesAndNewlines))
                await MainActor.run {
                    isSending = false
                    replyText = ""
                    showReplyComposer = false
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
    
    // MARK: - Avatar
    
    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 40, height: 40)
            
            Image(systemName: "envelope.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
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
        let direction = thread.latestEmail.direction
        
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

// MARK: - Timeline Email Message Row (for expanded view)

struct TimelineEmailMessageRow: View {
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

// MARK: - Timeline Reply Composer Sheet

struct TimelineReplyComposerSheet: View {
    let recipientName: String
    let recipientEmail: String
    let subject: String
    let onSend: (String) -> Void
    let onCancel: () -> Void
    
    @State private var messageText = ""
    @State private var ccText = ""
    @State private var bccText = ""
    @State private var showCc = false
    @State private var showBcc = false
    @State private var isSending = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("Cancel") {
                    onCancel()
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("Reply")
                    .font(.headline)
                
                Spacer()
                
                Button(action: send) {
                    if isSending {
                        ProgressView()
                            .scaleEffect(0.8)
                            .frame(width: 50)
                    } else {
                        Text("Send")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.plain)
                .foregroundColor(canSend ? .accentColor : .secondary)
                .disabled(!canSend || isSending)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // To field
                    HStack(alignment: .top) {
                        Text("To:")
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        // Recipient chip
                        HStack(spacing: 4) {
                            Text(recipientName)
                                .fontWeight(.medium)
                            if !recipientEmail.isEmpty {
                                Text("<\(recipientEmail)>")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(6)
                        
                        Spacer()
                        
                        // Cc/Bcc toggle
                        if !showCc || !showBcc {
                            Button(action: {
                                if !showCc {
                                    showCc = true
                                } else if !showBcc {
                                    showBcc = true
                                }
                            }) {
                                Text(!showCc ? "Cc/Bcc" : "Bcc")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    
                    // Cc field
                    if showCc {
                        Divider()
                            .padding(.leading, 50)
                        
                        HStack(alignment: .center) {
                            Text("Cc:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            TextField("Add recipients", text: $ccText)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    // Bcc field
                    if showBcc {
                        Divider()
                            .padding(.leading, 50)
                        
                        HStack(alignment: .center) {
                            Text("Bcc:")
                                .foregroundColor(.secondary)
                                .frame(width: 50, alignment: .leading)
                            
                            TextField("Add recipients", text: $bccText)
                                .textFieldStyle(.plain)
                                .font(.body)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                    
                    Divider()
                    
                    // Subject
                    HStack {
                        Text("Subject:")
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .leading)
                        
                        let displaySubject = subject.lowercased().hasPrefix("re:") ? subject : "Re: \(subject)"
                        Text(displaySubject)
                            .lineLimit(1)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    
                    Divider()
                    
                    // Message body
                    TextEditor(text: $messageText)
                        .font(.body)
                        .frame(minHeight: 180)
                        .padding(4)
                }
            }
        }
        .frame(width: 450, height: 400)
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func send() {
        guard canSend else { return }
        isSending = true
        onSend(messageText)
        dismiss()
    }
}
