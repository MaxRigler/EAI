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
