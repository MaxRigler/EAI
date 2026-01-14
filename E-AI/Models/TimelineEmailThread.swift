// TimelineEmailThread.swift
// Email thread model for timeline display (without archive/snooze functionality)

import Foundation

/// Represents a grouped email thread for display in contact/company timelines
/// This is a simplified version of EmailThread without archive-related properties
struct TimelineEmailThread: Identifiable {
    let id: String  // threadId
    let subject: String
    let displayName: String
    let emails: [Email]
    let latestEmail: Email
    
    /// Timestamp of the latest email in the thread
    var timestamp: Date { latestEmail.timestamp }
    
    /// Preview snippet from the latest email
    var snippet: String {
        latestEmail.body?.prefix(100).description ?? ""
    }
    
    /// The email address of the other party (for determining recipient when replying)
    var recipientEmail: String {
        if latestEmail.direction == .inbound {
            return latestEmail.senderEmail ?? ""
        } else {
            return latestEmail.recipientEmail ?? latestEmail.senderEmail ?? ""
        }
    }
    
    /// Initialize from a collection of emails in the same thread
    init(threadId: String, emails: [Email]) {
        self.id = threadId
        
        // Sort emails by timestamp (oldest first for display, we'll use latest for header)
        let sortedEmails = emails.sorted { $0.timestamp < $1.timestamp }
        self.emails = sortedEmails
        self.latestEmail = sortedEmails.last ?? emails[0]
        
        // Use subject from latest email (or any email if they're the same)
        self.subject = latestEmail.subject ?? "(No Subject)"
        
        // Determine display name (the other party's name/email)
        if latestEmail.direction == .inbound {
            self.displayName = latestEmail.senderName ?? latestEmail.senderEmail ?? "Unknown"
        } else {
            // For outbound, use the recipient email or name
            self.displayName = latestEmail.recipientEmail ?? "Unknown"
        }
    }
}
