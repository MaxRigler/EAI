// EmailSyncService.swift
// Syncs emails from Gmail to Supabase for E-AI contacts

import Foundation

/// Service for syncing Gmail emails to Supabase
class EmailSyncService {
    static let shared = EmailSyncService()
    
    private let gmailAPI = GmailAPIService.shared
    private let emailRepository = EmailRepository()
    private let contactRepository = ContactRepository()
    private let embeddingService = EmbeddingService.shared
    
    private var userEmail: String?
    private var isSyncing = false
    
    // Last sync timestamp stored in UserDefaults
    private let lastSyncKey = "eai_email_last_sync"
    
    private init() {}
    
    // MARK: - Public Properties
    
    var lastSyncTime: Date? {
        guard let timestamp = UserDefaults.standard.object(forKey: lastSyncKey) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    // MARK: - Sync Methods
    
    /// Sync all emails for a specific contact
    /// - Returns: Number of new emails synced
    @discardableResult
    func syncEmails(for contact: CRMContact) async throws -> Int {
        guard let email = contact.email, !email.isEmpty else {
            print("EmailSyncService: Contact \(contact.name) has no email address")
            return 0
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw EmailSyncError.notAuthenticated
        }
        
        print("EmailSyncService: Syncing emails for \(contact.name) (\(email))")
        
        // Get user's email for direction detection
        if userEmail == nil {
            userEmail = try? await gmailAPI.getUserEmail()
        }
        
        // Fetch emails from Gmail
        let gmailMessages = try await gmailAPI.fetchEmails(
            forEmailAddress: email,
            after: nil, // Start from today per user requirement
            maxResults: 100
        )
        
        // Get existing email IDs to avoid duplicates
        let existingIds = try await emailRepository.getExistingGmailIds(contactId: contact.id)
        
        // Filter new emails
        let newMessages = gmailMessages.filter { !existingIds.contains($0.id) }
        
        guard !newMessages.isEmpty else {
            print("EmailSyncService: No new emails for \(contact.name)")
            return 0
        }
        
        // Convert to Email models
        let emails = newMessages.compactMap { message -> Email? in
            guard let date = message.date else { return nil }
            
            let direction: Email.EmailDirection
            if let senderEmail = message.senderEmail?.lowercased(),
               let userEmail = userEmail?.lowercased() {
                direction = senderEmail == userEmail ? .outbound : .inbound
            } else {
                direction = .inbound
            }
            
            return Email(
                id: UUID(),
                contactId: contact.id,
                gmailId: message.id,
                threadId: message.threadId,
                subject: message.subject,
                body: message.body,
                direction: direction,
                timestamp: date,
                senderEmail: message.senderEmail,
                senderName: message.senderName,
                recipientEmail: message.to
            )
        }
        
        // Save to Supabase
        let savedEmails = try await emailRepository.createEmails(emails)
        
        // Check for new inbound emails on archived threads and unarchive them
        await unarchiveThreadsWithNewReplies(savedEmails)
        
        // Generate embeddings for new emails (in background)
        Task {
            await generateEmbeddings(for: savedEmails)
        }
        
        print("EmailSyncService: Synced \(savedEmails.count) new emails for \(contact.name)")
        return savedEmails.count
    }
    
    /// Sync emails for all contacts with email addresses
    /// - Returns: Total number of new emails synced
    @discardableResult
    func syncAllContactEmails() async throws -> Int {
        guard !isSyncing else {
            print("EmailSyncService: Sync already in progress")
            return 0
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw EmailSyncError.notAuthenticated
        }
        
        isSyncing = true
        defer { 
            isSyncing = false 
            updateLastSyncTime()
        }
        
        print("EmailSyncService: Starting full email sync")
        
        // Get all contacts with email addresses
        let contacts = try await contactRepository.fetchAllContacts()
        let contactsWithEmail = contacts.filter { $0.email != nil && !$0.email!.isEmpty }
        
        var totalSynced = 0
        
        for contact in contactsWithEmail {
            do {
                let count = try await syncEmails(for: contact)
                totalSynced += count
            } catch {
                print("EmailSyncService: Failed to sync emails for \(contact.name): \(error)")
                // Continue with other contacts
            }
        }
        
        print("EmailSyncService: Full sync complete. Total new emails: \(totalSynced)")
        return totalSynced
    }
    
    // MARK: - Send Email
    
    /// Send an email and save to Supabase
    func sendEmail(
        to contact: CRMContact,
        subject: String,
        body: String,
        cc: [String]? = nil,
        bcc: [String]? = nil
    ) async throws -> Email {
        guard let recipientEmail = contact.email, !recipientEmail.isEmpty else {
            throw EmailSyncError.noEmailAddress
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw EmailSyncError.notAuthenticated
        }
        
        print("EmailSyncService: Sending email to \(contact.name)")
        
        // Get user's email
        let senderEmail = try await gmailAPI.getUserEmail()
        
        // Get user's display name from settings
        let senderName = UserDefaults.standard.string(forKey: "eai_user_display_name")
        
        // Send via Gmail API
        let gmailMessage = try await gmailAPI.sendEmail(
            to: recipientEmail,
            subject: subject,
            body: body,
            from: senderEmail,
            fromName: senderName,
            cc: cc,
            bcc: bcc
        )
        
        // Create email record
        let email = Email(
            id: UUID(),
            contactId: contact.id,
            gmailId: gmailMessage.id,
            threadId: gmailMessage.threadId,
            subject: subject,
            body: body,
            direction: .outbound,
            timestamp: Date(),
            senderEmail: senderEmail,
            senderName: nil,
            recipientEmail: recipientEmail
        )
        
        // Save to Supabase
        let savedEmail = try await emailRepository.createEmail(email)
        
        // Generate embedding (in background)
        Task {
            await generateEmbeddings(for: [savedEmail])
        }
        
        print("EmailSyncService: Email sent and saved with ID \(savedEmail.id)")
        return savedEmail
    }
    
    /// Send an email to multiple recipients and save to Supabase
    func sendEmailToMultiple(
        toEmails: [String],
        subject: String,
        body: String,
        cc: [String]? = nil,
        bcc: [String]? = nil,
        primaryContactId: UUID
    ) async throws -> Email {
        guard !toEmails.isEmpty else {
            throw EmailSyncError.noEmailAddress
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw EmailSyncError.notAuthenticated
        }
        
        // Join multiple To addresses
        let toList = toEmails.joined(separator: ", ")
        print("EmailSyncService: Sending email to multiple recipients: \(toList)")
        
        // Get user's email
        let senderEmail = try await gmailAPI.getUserEmail()
        
        // Get user's display name from settings
        let senderName = UserDefaults.standard.string(forKey: "eai_user_display_name")
        
        // Send via Gmail API
        let gmailMessage = try await gmailAPI.sendEmail(
            to: toList,
            subject: subject,
            body: body,
            from: senderEmail,
            fromName: senderName,
            cc: cc,
            bcc: bcc
        )
        
        // Create email record (associated with primary contact)
        let email = Email(
            id: UUID(),
            contactId: primaryContactId,
            gmailId: gmailMessage.id,
            threadId: gmailMessage.threadId,
            subject: subject,
            body: body,
            direction: .outbound,
            timestamp: Date(),
            senderEmail: senderEmail,
            senderName: nil,
            recipientEmail: toList
        )
        
        // Save to Supabase
        let savedEmail = try await emailRepository.createEmail(email)
        
        // Generate embedding (in background)
        Task {
            await generateEmbeddings(for: [savedEmail])
        }
        
        print("EmailSyncService: Email sent to multiple recipients and saved with ID \(savedEmail.id)")
        return savedEmail
    }
    
    // MARK: - Private Helpers
    
    private func updateLastSyncTime() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastSyncKey)
    }
    
    private func generateEmbeddings(for emails: [Email]) async {
        for email in emails {
            do {
                // Combine subject and body for embedding
                let text = [email.subject, email.body]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
                
                guard !text.isEmpty else { continue }
                
                let embedding = try await embeddingService.generateEmbedding(for: text)
                try await emailRepository.updateEmailEmbedding(emailId: email.id, embedding: embedding)
            } catch {
                print("EmailSyncService: Failed to generate embedding for email \(email.id): \(error)")
            }
        }
    }
    
    /// Check for new inbound emails on archived threads and unarchive them
    private func unarchiveThreadsWithNewReplies(_ emails: [Email]) async {
        // Get thread IDs for new inbound emails
        let inboundThreadIds = Set(emails
            .filter { $0.direction == .inbound }
            .compactMap { $0.threadId })
        
        guard !inboundThreadIds.isEmpty else { return }
        
        for threadId in inboundThreadIds {
            do {
                // Check if any email in this thread is archived
                let threadEmails = try await emailRepository.fetchEmailsForThread(threadId: threadId)
                let isArchived = threadEmails.contains { $0.isArchived }
                
                if isArchived {
                    // Unarchive the thread and clear any reminder
                    try await emailRepository.clearReminderAndUnarchive(threadId: threadId)
                    print("EmailSyncService: Auto-unarchived thread \(threadId) due to new reply")
                }
            } catch {
                print("EmailSyncService: Failed to check/unarchive thread \(threadId): \(error)")
            }
        }
    }
}

// MARK: - Errors

enum EmailSyncError: LocalizedError {
    case notAuthenticated
    case noEmailAddress
    case syncFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Gmail. Please connect your Gmail account in Settings."
        case .noEmailAddress:
            return "This contact doesn't have an email address."
        case .syncFailed(let message):
            return "Email sync failed: \(message)"
        }
    }
}
