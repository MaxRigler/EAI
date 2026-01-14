// MessagesViewModel.swift
// ViewModel for managing email thread display

import Foundation
import Combine

/// Represents a grouped email thread for display
struct EmailThread: Identifiable {
    let id: String  // threadId
    let subject: String
    let participants: [String]  // Contact names or emails
    let latestMessage: Email
    let messages: [Email]
    let unreadCount: Int
    
    var displayName: String {
        if let first = participants.first {
            if participants.count > 1 {
                return "\(first) +\(participants.count - 1)"
            }
            return first
        }
        return "Unknown"
    }
    
    var snippet: String {
        latestMessage.body?.prefix(100).description ?? "(No content)"
    }
    
    var timestamp: Date {
        latestMessage.timestamp
    }
}

@MainActor
class MessagesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var threads: [EmailThread] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var searchText = ""
    
    // MARK: - Dependencies
    
    private let emailRepository = EmailRepository()
    private let contactRepository = ContactRepository()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredThreads: [EmailThread] {
        if searchText.isEmpty {
            return threads
        }
        return threads.filter { thread in
            thread.subject.localizedCaseInsensitiveContains(searchText) ||
            thread.displayName.localizedCaseInsensitiveContains(searchText) ||
            thread.snippet.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Public Methods
    
    func loadThreads() {
        isLoading = true
        error = nil
        
        Task {
            do {
                // Fetch all contacts to get their emails
                let contacts = try await contactRepository.fetchAllContacts()
                let contactIds = contacts.map { $0.id }
                
                // Fetch emails for all contacts
                let emails = try await emailRepository.fetchEmails(contactIds: contactIds)
                
                // Build a contact lookup for display names
                let contactLookup = Dictionary(uniqueKeysWithValues: contacts.map { ($0.id, $0) })
                
                // Group emails by threadId
                let groupedThreads = groupEmailsIntoThreads(emails, contactLookup: contactLookup)
                
                await MainActor.run {
                    self.threads = groupedThreads
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = error
                    self.isLoading = false
                }
            }
        }
    }
    
    func refresh() {
        loadThreads()
    }
    
    // MARK: - Private Methods
    
    private func groupEmailsIntoThreads(_ emails: [Email], contactLookup: [UUID: CRMContact]) -> [EmailThread] {
        // Group by threadId, or gmailId if no threadId
        var threadGroups: [String: [Email]] = [:]
        
        for email in emails {
            let key = email.threadId ?? email.gmailId
            if threadGroups[key] != nil {
                threadGroups[key]?.append(email)
            } else {
                threadGroups[key] = [email]
            }
        }
        
        // Convert groups to EmailThread objects
        var threads: [EmailThread] = []
        
        for (threadId, emailsInThread) in threadGroups {
            // Sort emails by timestamp (newest first for latest, but keep chronological for display)
            let sortedEmails = emailsInThread.sorted { $0.timestamp < $1.timestamp }
            guard let latestEmail = sortedEmails.last else { continue }
            
            // Build participants list from contacts
            var participants: [String] = []
            for email in emailsInThread {
                if let contactId = email.contactId, let contact = contactLookup[contactId] {
                    if !participants.contains(contact.name) {
                        participants.append(contact.name)
                    }
                } else if let senderName = email.senderName, !participants.contains(senderName) {
                    participants.append(senderName)
                } else if let senderEmail = email.senderEmail, !participants.contains(senderEmail) {
                    participants.append(senderEmail)
                }
            }
            
            let thread = EmailThread(
                id: threadId,
                subject: latestEmail.subject ?? "(No Subject)",
                participants: participants,
                latestMessage: latestEmail,
                messages: sortedEmails,
                unreadCount: 0  // TODO: Track read/unread status
            )
            
            threads.append(thread)
        }
        
        // Sort threads by latest message timestamp (newest first)
        return threads.sorted { $0.timestamp > $1.timestamp }
    }
}
