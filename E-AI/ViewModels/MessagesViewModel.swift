// MessagesViewModel.swift
// ViewModel for managing email thread display

import Foundation
import Combine

/// Filter for message display
enum MessageFilter: String, CaseIterable {
    case active = "Active Messages"
    case archived = "Archived Messages"
}

/// Sub-filter for archived messages
enum ArchivedSubFilter: String, CaseIterable {
    case all = "All"
    case archived = "Archived"
    case scheduled = "Scheduled"
}

/// Represents a grouped email thread for display
struct EmailThread: Identifiable {
    let id: String  // threadId
    let subject: String
    let participants: [String]  // Contact names or emails
    let latestMessage: Email
    let messages: [Email]
    let unreadCount: Int
    let isArchived: Bool
    let reminderDate: Date?  // For snoozed threads
    let contact: CRMContact?  // The contact for this thread
    let companyContact: CRMContact?  // Company the contact is associated with
    
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
    
    /// Get the email address of the other party in the thread
    var recipientEmail: String {
        // If latest message was inbound, use sender email; otherwise use recipient
        if latestMessage.direction == .inbound {
            return latestMessage.senderEmail ?? ""
        } else {
            return latestMessage.recipientEmail ?? latestMessage.senderEmail ?? ""
        }
    }
}

@MainActor
class MessagesViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var threads: [EmailThread] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var error: Error?
    @Published var searchText = ""
    @Published var currentFilter: MessageFilter = .active
    @Published var archivedSubFilter: ArchivedSubFilter = .all
    
    // MARK: - Dependencies
    
    private let emailRepository = EmailRepository()
    private let contactRepository = ContactRepository()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredThreads: [EmailThread] {
        var result = threads
        
        // Filter by archive status
        switch currentFilter {
        case .active:
            result = result.filter { !$0.isArchived }
        case .archived:
            result = result.filter { $0.isArchived }
            
            // Apply sub-filter for archived
            switch archivedSubFilter {
            case .all:
                break  // Show all archived
            case .archived:
                result = result.filter { $0.reminderDate == nil }
            case .scheduled:
                result = result.filter { $0.reminderDate != nil }
            }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            result = result.filter { thread in
                thread.subject.localizedCaseInsensitiveContains(searchText) ||
                thread.displayName.localizedCaseInsensitiveContains(searchText) ||
                thread.snippet.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return result
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
    
    /// Sync emails from Gmail for all contacts
    func syncEmails() async {
        guard !isSyncing else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        do {
            let count = try await EmailSyncService.shared.syncAllContactEmails()
            print("MessagesViewModel: Synced \(count) new emails")
            
            // Also check for due reminders
            checkDueReminders()
            
            // Reload threads to show new emails
            loadThreads()
        } catch {
            print("MessagesViewModel: Failed to sync emails: \(error)")
            self.error = error
        }
    }
    
    /// Archive a thread
    func archiveThread(_ thread: EmailThread) async {
        do {
            try await emailRepository.archiveThread(threadId: thread.id)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                let updatedThread = EmailThread(
                    id: thread.id,
                    subject: thread.subject,
                    participants: thread.participants,
                    latestMessage: thread.latestMessage,
                    messages: thread.messages,
                    unreadCount: thread.unreadCount,
                    isArchived: true,
                    reminderDate: nil,
                    contact: thread.contact,
                    companyContact: thread.companyContact
                )
                threads[index] = updatedThread
            }
        } catch {
            print("MessagesViewModel: Failed to archive thread: \(error)")
            self.error = error
        }
    }
    
    /// Unarchive a thread
    func unarchiveThread(_ thread: EmailThread) async {
        do {
            try await emailRepository.unarchiveThread(threadId: thread.id)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                let updatedThread = EmailThread(
                    id: thread.id,
                    subject: thread.subject,
                    participants: thread.participants,
                    latestMessage: thread.latestMessage,
                    messages: thread.messages,
                    unreadCount: thread.unreadCount,
                    isArchived: false,
                    reminderDate: nil,
                    contact: thread.contact,
                    companyContact: thread.companyContact
                )
                threads[index] = updatedThread
            }
        } catch {
            print("MessagesViewModel: Failed to unarchive thread: \(error)")
            self.error = error
        }
    }
    
    /// Reply to a thread
    func replyToThread(_ thread: EmailThread, body: String) async throws {
        // Get the latest message to reply to
        let latestMessage = thread.latestMessage
        
        // Determine the recipient email - if the latest was inbound, reply to sender, otherwise use same recipient
        let recipientEmail: String
        if latestMessage.direction == .inbound {
            recipientEmail = latestMessage.senderEmail ?? ""
        } else {
            recipientEmail = latestMessage.recipientEmail ?? latestMessage.senderEmail ?? ""
        }
        
        guard !recipientEmail.isEmpty else {
            throw ReplyError.noRecipientEmail
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw ReplyError.notAuthenticated
        }
        
        // Build subject with Re: prefix if not already present
        let subject: String
        if let originalSubject = latestMessage.subject {
            if originalSubject.lowercased().hasPrefix("re:") {
                subject = originalSubject
            } else {
                subject = "Re: \(originalSubject)"
            }
        } else {
            subject = "Re: (No Subject)"
        }
        
        // Get sender info from settings and Gmail
        let senderName = UserDefaults.standard.string(forKey: "eai_user_display_name")
        let senderEmail = try await GmailAPIService.shared.getUserEmail()
        
        // Send via Gmail API with sender name and email
        let gmailMessage = try await GmailAPIService.shared.sendEmail(
            to: recipientEmail,
            subject: subject,
            body: body,
            from: senderEmail,
            fromName: senderName,
            replyToMessageId: latestMessage.gmailId,
            threadId: thread.id
        )
        
        // Create Email model and save to Supabase
        let email = Email(
            contactId: latestMessage.contactId,
            gmailId: gmailMessage.id,
            threadId: gmailMessage.threadId,
            subject: subject,
            body: body,
            direction: .outbound,
            timestamp: Date(),
            senderEmail: senderEmail,
            senderName: senderName,
            recipientEmail: recipientEmail
        )
        
        let savedEmail = try await emailRepository.createEmail(email)
        print("MessagesViewModel: Reply sent and saved with ID \(savedEmail.id)")
        
        // Refresh threads to show the new message
        loadThreads()
    }
    
    /// Snooze a thread until a specific date
    func snoozeThread(_ thread: EmailThread, until date: Date) async {
        do {
            try await emailRepository.snoozeThread(threadId: thread.id, until: date)
            // Update local state
            if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                let updatedThread = EmailThread(
                    id: thread.id,
                    subject: thread.subject,
                    participants: thread.participants,
                    latestMessage: thread.latestMessage,
                    messages: thread.messages,
                    unreadCount: thread.unreadCount,
                    isArchived: true,
                    reminderDate: date,
                    contact: thread.contact,
                    companyContact: thread.companyContact
                )
                threads[index] = updatedThread
            }
        } catch {
            print("MessagesViewModel: Failed to snooze thread: \(error)")
            self.error = error
        }
    }
    
    /// Check for due reminders and unarchive them
    func checkDueReminders() {
        Task {
            do {
                let dueEmails = try await emailRepository.fetchDueReminders()
                
                // Get unique thread IDs
                let threadIds = Set(dueEmails.compactMap { $0.threadId })
                
                for threadId in threadIds {
                    try await emailRepository.clearReminderAndUnarchive(threadId: threadId)
                }
                
                if !threadIds.isEmpty {
                    print("MessagesViewModel: Unarchived \(threadIds.count) threads with due reminders")
                    loadThreads()
                }
            } catch {
                print("MessagesViewModel: Failed to check due reminders: \(error)")
            }
        }
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
            
            // Build participants list from contacts and find the primary contact
            var participants: [String] = []
            var threadContact: CRMContact?
            
            for email in emailsInThread {
                if let contactId = email.contactId, let contact = contactLookup[contactId] {
                    if threadContact == nil {
                        threadContact = contact
                    }
                    if !participants.contains(contact.name) {
                        participants.append(contact.name)
                    }
                } else if let senderName = email.senderName, !participants.contains(senderName) {
                    participants.append(senderName)
                } else if let senderEmail = email.senderEmail, !participants.contains(senderEmail) {
                    participants.append(senderEmail)
                }
            }
            
            // Look up company contact if the primary contact has a companyId
            var companyContact: CRMContact?
            if let contact = threadContact, let companyId = contact.companyId {
                companyContact = contactLookup[companyId]
            }
            
            // Thread is archived if any email is archived (typically all will be)
            let isArchived = emailsInThread.contains { $0.isArchived }
            
            // Get the reminder date from any email in the thread
            let reminderDate = emailsInThread.first { $0.reminderDate != nil }?.reminderDate
            
            let thread = EmailThread(
                id: threadId,
                subject: latestEmail.subject ?? "(No Subject)",
                participants: participants,
                latestMessage: latestEmail,
                messages: sortedEmails,
                unreadCount: 0,  // TODO: Track read/unread status
                isArchived: isArchived,
                reminderDate: reminderDate,
                contact: threadContact,
                companyContact: companyContact
            )
            
            threads.append(thread)
        }
        
        // Sort threads by latest message timestamp (newest first)
        return threads.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Reply Errors

enum ReplyError: LocalizedError {
    case noRecipientEmail
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .noRecipientEmail:
            return "Unable to determine recipient email address."
        case .notAuthenticated:
            return "Please sign in to Gmail to send replies."
        }
    }
}

