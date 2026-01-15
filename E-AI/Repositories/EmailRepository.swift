// EmailRepository.swift
// CRUD operations for emails in Supabase

import Foundation

class EmailRepository {
    
    // MARK: - Fetch Emails
    
    /// Fetch all emails for a contact
    func fetchEmails(contactId: UUID) async throws -> [Email] {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Email] = try await client
            .from("emails")
            .select()
            .eq("contact_id", value: contactId.uuidString)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    /// Fetch emails for multiple contacts
    func fetchEmails(contactIds: [UUID]) async throws -> [Email] {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let ids = contactIds.map { $0.uuidString }
        
        let response: [Email] = try await client
            .from("emails")
            .select()
            .in("contact_id", values: ids)
            .order("timestamp", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    /// Check if an email exists by Gmail ID
    func emailExists(gmailId: String) async throws -> Bool {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Email] = try await client
            .from("emails")
            .select("id")
            .eq("gmail_id", value: gmailId)
            .limit(1)
            .execute()
            .value
        
        return !response.isEmpty
    }
    
    /// Get existing Gmail IDs for a contact (for deduplication)
    func getExistingGmailIds(contactId: UUID) async throws -> Set<String> {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        struct GmailIdRow: Codable {
            let gmailId: String
            
            enum CodingKeys: String, CodingKey {
                case gmailId = "gmail_id"
            }
        }
        
        let response: [GmailIdRow] = try await client
            .from("emails")
            .select("gmail_id")
            .eq("contact_id", value: contactId.uuidString)
            .execute()
            .value
        
        return Set(response.map { $0.gmailId })
    }
    
    /// Fetch all emails for a specific thread
    func fetchEmailsForThread(threadId: String) async throws -> [Email] {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let response: [Email] = try await client
            .from("emails")
            .select()
            .eq("thread_id", value: threadId)
            .execute()
            .value
        
        return response
    }
    
    // MARK: - Create/Update Emails
    
    /// Save a new email
    func createEmail(_ email: Email) async throws -> Email {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let payload = EmailInsertPayload(
            id: email.id,
            contactId: email.contactId,
            gmailId: email.gmailId,
            threadId: email.threadId,
            subject: email.subject,
            body: email.body,
            direction: email.direction.rawValue,
            timestamp: email.timestamp,
            senderEmail: email.senderEmail,
            senderName: email.senderName,
            recipientEmail: email.recipientEmail
        )
        
        let response: [Email] = try await client
            .from("emails")
            .insert(payload)
            .select()
            .execute()
            .value
        
        guard let created = response.first else {
            throw RepositoryError.createFailed
        }
        
        print("EmailRepository: Created email with ID \(created.id)")
        return created
    }
    
    /// Save multiple emails (batch insert)
    func createEmails(_ emails: [Email]) async throws -> [Email] {
        guard !emails.isEmpty else { return [] }
        
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let payloads = emails.map { email in
            EmailInsertPayload(
                id: email.id,
                contactId: email.contactId,
                gmailId: email.gmailId,
                threadId: email.threadId,
                subject: email.subject,
                body: email.body,
                direction: email.direction.rawValue,
                timestamp: email.timestamp,
                senderEmail: email.senderEmail,
                senderName: email.senderName,
                recipientEmail: email.recipientEmail
            )
        }
        
        let response: [Email] = try await client
            .from("emails")
            .insert(payloads)
            .select()
            .execute()
            .value
        
        print("EmailRepository: Created \(response.count) emails")
        return response
    }
    
    /// Update email embedding using RPC function
    func updateEmailEmbedding(emailId: UUID, embedding: [Float]) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Format embedding for pgvector
        let vectorString = formatEmbeddingForPgvector(embedding)
        
        try await client.rpc(
            "update_email_embedding",
            params: [
                "p_email_id": emailId.uuidString,
                "p_embedding": vectorString
            ]
        ).execute()
        
        print("EmailRepository: Updated embedding for email \(emailId)")
    }
    
    // MARK: - Archive/Unarchive
    
    /// Archive all emails in a thread
    /// This also clears any reminder date/context so threads don't return after being re-archived
    func archiveThread(threadId: String) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Use a struct that explicitly encodes null values
        // Swift's default Encodable skips nil values, but we need to send null to Supabase
        struct ArchivePayload: Encodable {
            let is_archived: Bool
            
            // Custom encoding to explicitly encode null values
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(is_archived, forKey: .is_archived)
                // Explicitly encode nil as null for reminder_date and reminder_context
                try container.encodeNil(forKey: .reminder_date)
                try container.encodeNil(forKey: .reminder_context)
            }
            
            enum CodingKeys: String, CodingKey {
                case is_archived
                case reminder_date
                case reminder_context
            }
        }
        
        // Clear reminder_date and reminder_context when archiving
        // This ensures threads don't return again after being manually re-archived
        let payload = ArchivePayload(is_archived: true)
        
        try await client
            .from("emails")
            .update(payload)
            .eq("thread_id", value: threadId)
            .execute()
        
        print("EmailRepository: Archived thread \(threadId) and cleared reminder")
    }
    
    /// Unarchive all emails in a thread
    func unarchiveThread(threadId: String) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        try await client
            .from("emails")
            .update(["is_archived": false])
            .eq("thread_id", value: threadId)
            .execute()
        
        print("EmailRepository: Unarchived thread \(threadId)")
    }
    
    // MARK: - Snooze/Remind
    
    /// Snooze a thread until a specific date (archive with reminder)
    func snoozeThread(threadId: String, until reminderDate: Date, context: String? = nil) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let formatter = ISO8601DateFormatter()
        let dateString = formatter.string(from: reminderDate)
        
        // Use a struct for proper encoding
        struct SnoozePayload: Encodable {
            let is_archived: Bool
            let reminder_date: String
            let reminder_context: String?
        }
        
        let payload = SnoozePayload(is_archived: true, reminder_date: dateString, reminder_context: context)
        
        try await client
            .from("emails")
            .update(payload)
            .eq("thread_id", value: threadId)
            .execute()
        
        print("EmailRepository: Snoozed thread \(threadId) until \(reminderDate) with context: \(context ?? "none")")
    }
    
    /// Clear reminder and unarchive a thread
    func clearReminderAndUnarchive(threadId: String) async throws {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        // Use a struct that explicitly encodes null values
        // Swift's default Encodable skips nil values, but we need to send null to Supabase
        struct ClearReminderPayload: Encodable {
            let is_archived: Bool
            
            // Custom encoding to explicitly encode null values
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(is_archived, forKey: .is_archived)
                // Explicitly encode nil as null for reminder_date and reminder_context
                try container.encodeNil(forKey: .reminder_date)
                try container.encodeNil(forKey: .reminder_context)
            }
            
            enum CodingKeys: String, CodingKey {
                case is_archived
                case reminder_date
                case reminder_context
            }
        }
        
        let payload = ClearReminderPayload(is_archived: false)
        
        try await client
            .from("emails")
            .update(payload)
            .eq("thread_id", value: threadId)
            .execute()
        
        print("EmailRepository: Cleared reminder and unarchived thread \(threadId)")
    }
    
    /// Fetch all emails with due reminders (reminder_date <= now)
    func fetchDueReminders() async throws -> [Email] {
        guard let client = await SupabaseManager.shared.getClient() else {
            throw RepositoryError.notInitialized
        }
        
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let nowString = formatter.string(from: now)
        
        let response = try await client
            .from("emails")
            .select()
            .lte("reminder_date", value: nowString)
            .eq("is_archived", value: true)
            .execute()
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatters: [DateFormatter] = {
                let iso = DateFormatter()
                iso.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZZZZZ"
                let isoSimple = DateFormatter()
                isoSimple.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                return [iso, isoSimple]
            }()
            
            for formatter in formatters {
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date")
        }
        
        return try decoder.decode([Email].self, from: response.data)
    }
    
    // MARK: - Private Helpers
    
    private func formatEmbeddingForPgvector(_ embedding: [Float]) -> String {
        let values = embedding.map { String(format: "%.8f", $0) }.joined(separator: ",")
        return "[\(values)]"
    }
}

// MARK: - Payload Types

private struct EmailInsertPayload: Encodable {
    let id: UUID
    let contactId: UUID?
    let gmailId: String
    let threadId: String?
    let subject: String?
    let body: String?
    let direction: String
    let timestamp: Date
    let senderEmail: String?
    let senderName: String?
    let recipientEmail: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case contactId = "contact_id"
        case gmailId = "gmail_id"
        case threadId = "thread_id"
        case subject
        case body
        case direction
        case timestamp
        case senderEmail = "sender_email"
        case senderName = "sender_name"
        case recipientEmail = "recipient_email"
    }
}
