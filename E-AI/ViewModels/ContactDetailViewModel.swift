// ContactDetailViewModel.swift
// Contact detail and timeline state

import Foundation
import AppKit

// MARK: - Notification Names

extension Notification.Name {
    static let contactsDidChange = Notification.Name("contactsDidChange")
}

@MainActor
class ContactDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published var contact: CRMContact
    @Published var isSaving = false
    
    @Published var timelineItems: [TimelineItem] = []
    @Published var emailThreads: [TimelineEmailThread] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Company/People associations
    @Published var companyContact: CRMContact?
    @Published var associatedPeople: [CRMContact] = []
    @Published var isLoadingAssociations = false
    
    // Tasks properties
    @Published var tasks: [AppTask] = []
    @Published var selectedTaskFilter: TaskFilter = .open
    @Published var isLoadingTasks = false
    
    // iMessage sync properties
    @Published var isSyncingMessages = false
    @Published var syncResult: SyncResult?
    @Published var showPermissionAlert = false
    
    // Email sync properties
    @Published var isSyncingEmails = false
    @Published var emailSyncResult: SyncResult?
    
    enum SyncResult {
        case success(count: Int)
        case error(message: String)
    }
    
    enum TaskFilter: String, CaseIterable {
        case open = "Open"
        case completed = "Completed"
    }
    
    var filteredTasks: [AppTask] {
        switch selectedTaskFilter {
        case .open:
            return tasks.filter { $0.status == .open }
        case .completed:
            return tasks.filter { $0.status == .completed }
        }
    }
    
    // Check if contact has phone or email for iMessage sync
    var canSyncIMessages: Bool {
        contact.phone != nil || contact.email != nil
    }
    
    // Check if contact can sync emails
    var canSyncEmails: Bool {
        contact.email != nil && _isGmailConnected
    }
    
    // Check if Gmail is connected (cached)
    @Published private(set) var _isGmailConnected: Bool = false
    var isGmailConnected: Bool { _isGmailConnected }
    
    // MARK: - Private Properties
    
    private let recordingRepository = RecordingRepository()
    private let dailyRepository = DailyRepository()
    private let taskRepository = TaskRepository()
    private let contactRepository = ContactRepository()
    private let contactsManager = ContactsManager.shared
    private let imessageChunkManager = IMessageChunkManager.shared
    private let imessageRepository = IMessageRepository()
    private let emailRepository = EmailRepository()
    private let labelRepository = LabelRepository()
    
    // Labels properties
    @Published var labels: [ContactLabel] = []
    @Published var allLabels: [ContactLabel] = []
    @Published var isLoadingLabels = false
    
    // MARK: - Initialization
    
    init(contact: CRMContact) {
        self.contact = contact
        self._isGmailConnected = GmailAuthService.shared.isAuthenticated
    }
    
    func refreshGmailStatus() {
        _isGmailConnected = GmailAuthService.shared.isAuthenticated
    }
    
    // MARK: - Save Contact (Two-Way Sync)
    
    func saveContact(_ updatedContact: CRMContact) {
        isSaving = true
        
        Task {
            do {
                var contactToSave = updatedContact
                
                // If this contact is associated with a company and has no domain, inherit company's domain
                if let companyId = contactToSave.companyId,
                   (contactToSave.domain == nil || contactToSave.domain?.isEmpty == true) {
                    if let company = try await contactRepository.fetchContact(id: companyId),
                       let companyDomain = company.domain, !companyDomain.isEmpty {
                        contactToSave.domain = companyDomain
                        print("ContactDetailViewModel: Inherited domain '\(companyDomain)' from company '\(company.name)'")
                    }
                }
                
                // 1. Update in Supabase
                let savedContact = try await contactRepository.updateContact(contactToSave)
                
                // 2. Update local state immediately (Supabase succeeded)
                self.contact = savedContact
                
                // 3. Reload associations to refresh the Associated Company section
                loadAssociations()
                
                // 4. If linked to Apple Contacts AND authorized, update there too
                if let appleContactId = savedContact.appleContactId {
                    // Check authorization before attempting update
                    contactsManager.checkAuthorizationStatus()
                    
                    if contactsManager.authorizationStatus == .authorized {
                        do {
                            if let appleContact = try contactsManager.getContact(withIdentifier: appleContactId) {
                                // Parse name into first/last
                                let nameParts = savedContact.name.components(separatedBy: " ")
                                let firstName = nameParts.first ?? savedContact.name
                                let lastName = nameParts.dropFirst().joined(separator: " ")
                                
                                let updates = ContactUpdates(
                                    firstName: firstName,
                                    lastName: lastName.isEmpty ? nil : lastName,
                                    company: savedContact.company,
                                    email: savedContact.email,
                                    phone: savedContact.phone
                                )
                                
                                _ = try await contactsManager.updateContact(appleContact, updates: updates)
                                print("ContactDetailViewModel: Updated Apple Contact successfully")
                            }
                        } catch {
                            // Log but don't fail - Supabase update already succeeded
                            print("ContactDetailViewModel: Failed to update Apple Contact: \(error)")
                        }
                    } else {
                        print("ContactDetailViewModel: Skipping Apple Contacts update - not authorized")
                    }
                }
                
                // 5. If this is a company with a domain, propagate domain to all associated contacts
                if savedContact.isCompany,
                   let domain = savedContact.domain, !domain.isEmpty {
                    do {
                        try await contactRepository.propagateCompanyDomain(companyId: savedContact.id, domain: domain)
                    } catch {
                        // Log but don't fail - company update already succeeded
                        print("ContactDetailViewModel: Failed to propagate domain to contacts: \(error)")
                    }
                }
                
                isSaving = false
                
            } catch {
                self.error = error
                isSaving = false
            }
        }
    }
    
    // MARK: - Delete Contact
    
    /// Published property to track if contact was deleted (triggers dismiss in view)
    @Published var isDeleted = false
    @Published var isDeleting = false
    
    /// Delete the contact from E-AI (Supabase only, preserves iCloud contact)
    func deleteContact() {
        print("ContactDetailViewModel: deleteContact() called for '\(contact.name)'")
        isDeleting = true
        
        Task {
            do {
                print("ContactDetailViewModel: Calling repository.deleteContact...")
                try await contactRepository.deleteContact(contact)
                print("ContactDetailViewModel: Successfully deleted contact '\(contact.name)' from E-AI")
                isDeleted = true
                isDeleting = false
                
                // Post notification to refresh contacts list
                print("ContactDetailViewModel: Posting contactsDidChange notification")
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            } catch {
                self.error = error
                print("ContactDetailViewModel: Failed to delete contact: \(error)")
                isDeleting = false
            }
        }
    }
    
    // MARK: - Load Timeline

    
    func loadTimeline() {
        isLoading = true
        
        Task {
            do {
                var items: [TimelineItem] = []
                
                guard let client = await SupabaseManager.shared.getClient() else {
                    isLoading = false
                    return
                }
                
                // Fetch recordings for this contact (and associated contacts for companies/individuals)
                var allRecordings: [Recording] = []
                var existingRecordingIds: Set<UUID> = []
                
                // Always fetch recordings for the current contact
                let directRecordings = try await recordingRepository.fetchRecordings(contactId: contact.id)
                allRecordings.append(contentsOf: directRecordings)
                existingRecordingIds = Set(directRecordings.map { $0.id })
                
                if contact.isCompany {
                    // For companies: also fetch recordings from all associated people
                    let associatedPeople = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                    for person in associatedPeople {
                        let personRecordings = try await recordingRepository.fetchRecordings(contactId: person.id)
                        let uniqueRecordings = personRecordings.filter { !existingRecordingIds.contains($0.id) }
                        allRecordings.append(contentsOf: uniqueRecordings)
                        existingRecordingIds.formUnion(uniqueRecordings.map { $0.id })
                    }
                } else if let companyId = contact.companyId {
                    // For individuals: also include company's direct recordings (if any)
                    let companyRecordings = try await recordingRepository.fetchRecordings(contactId: companyId)
                    let uniqueRecordings = companyRecordings.filter { !existingRecordingIds.contains($0.id) }
                    allRecordings.append(contentsOf: uniqueRecordings)
                }
                
                let recordings = allRecordings
                
                if !recordings.isEmpty {
                    let recordingIds = recordings.map { $0.id.uuidString.lowercased() }
                    
                    // Batch fetch all recording types
                    let allRecordingTypes: [RecordingType] = (try? await client
                        .from("recording_types")
                        .select()
                        .execute()
                        .value) ?? []
                    let recordingTypeMap = Dictionary(uniqueKeysWithValues: allRecordingTypes.map { ($0.id, $0) })
                    
                    // Batch fetch all summaries for these recordings
                    let allSummaries: [Summary] = (try? await client
                        .from("summaries")
                        .select()
                        .in("recording_id", values: recordingIds)
                        .execute()
                        .value) ?? []
                    let summaryMap = Dictionary(uniqueKeysWithValues: allSummaries.map { ($0.recordingId, $0) })
                    
                    // Batch fetch all speakers for these recordings
                    let allSpeakers: [RecordingSpeaker] = (try? await client
                        .from("recording_speakers")
                        .select()
                        .in("recording_id", values: recordingIds)
                        .execute()
                        .value) ?? []
                    
                    // Group speakers by recording
                    var speakersByRecording: [UUID: [RecordingSpeaker]] = [:]
                    for speaker in allSpeakers {
                        speakersByRecording[speaker.recordingId, default: []].append(speaker)
                    }
                    
                    // Collect all unique contact IDs needed
                    let contactIds = Set(allSpeakers.compactMap { $0.contactId }).map { $0.uuidString.lowercased() }
                    
                    // Batch fetch all contacts
                    var contactMap: [UUID: CRMContact] = [:]
                    if !contactIds.isEmpty {
                        let allContacts: [CRMContact] = (try? await client
                            .from("crm_contacts")
                            .select()
                            .in("id", values: contactIds)
                            .execute()
                            .value) ?? []
                        contactMap = Dictionary(uniqueKeysWithValues: allContacts.map { ($0.id, $0) })
                    }
                    
                    // Build timeline items from recordings
                    for recording in recordings {
                        // Get recording type name
                        var typeName = "Call"
                        if let typeId = recording.recordingTypeId,
                           let recordingType = recordingTypeMap[typeId] {
                            typeName = recordingType.name
                        }
                        
                        // Get summary
                        let summary = summaryMap[recording.id]
                        
                        // Get contacts for this recording
                        let speakers = speakersByRecording[recording.id] ?? []
                        var recordingContacts: [CRMContact] = []
                        var addedContactIds: Set<UUID> = []
                        
                        for speaker in speakers {
                            if let contactId = speaker.contactId,
                               let speakerContact = contactMap[contactId] {
                                // Add the speaker contact
                                if !addedContactIds.contains(speakerContact.id) {
                                    recordingContacts.append(speakerContact)
                                    addedContactIds.insert(speakerContact.id)
                                }
                                
                                // Also add the company if this contact is associated with one
                                if let companyId = speakerContact.companyId {
                                    if !addedContactIds.contains(companyId) {
                                        // Try to get company from contact map first
                                        if let companyContact = contactMap[companyId] {
                                            recordingContacts.insert(companyContact, at: 0) // Company first
                                            addedContactIds.insert(companyId)
                                        } else {
                                            // Fetch the company contact if not in map
                                            if let companyContact = try? await contactRepository.fetchContact(id: companyId) {
                                                recordingContacts.insert(companyContact, at: 0) // Company first
                                                addedContactIds.insert(companyId)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        var item = TimelineItem(
                            id: recording.id,
                            type: .recording,
                            title: typeName,
                            content: summary?.summaryText ?? "Processing...",
                            date: recording.createdAt,
                            sourceId: recording.id
                        )
                        item.contacts = recordingContacts
                        items.append(item)
                    }
                }
                
                // Fetch comments (including from associated contacts)
                var allComments: [Comment] = []
                var existingCommentIds: Set<UUID> = []
                
                let directComments = try await dailyRepository.fetchComments(contactId: contact.id)
                allComments.append(contentsOf: directComments)
                existingCommentIds = Set(directComments.map { $0.id })
                
                if contact.isCompany {
                    // For companies: also fetch comments from all associated people
                    let associatedPeople = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                    for person in associatedPeople {
                        let personComments = try await dailyRepository.fetchComments(contactId: person.id)
                        let uniqueComments = personComments.filter { !existingCommentIds.contains($0.id) }
                        allComments.append(contentsOf: uniqueComments)
                        existingCommentIds.formUnion(uniqueComments.map { $0.id })
                    }
                } else if let companyId = contact.companyId {
                    // For individuals: also include company's comments
                    let companyComments = try await dailyRepository.fetchComments(contactId: companyId)
                    let uniqueComments = companyComments.filter { !existingCommentIds.contains($0.id) }
                    allComments.append(contentsOf: uniqueComments)
                }
                
                for comment in allComments {
                    let item = TimelineItem(
                        id: comment.id,
                        type: .comment,
                        title: "Note",
                        content: comment.content,
                        date: comment.createdAt,
                        sourceId: nil
                    )
                    items.append(item)
                }
                
                // Fetch iMessage chunks (including from associated contacts)
                var allIMChunks: [IMessageChunk] = []
                var existingChunkIds: Set<UUID> = []
                
                let directChunks = try await imessageRepository.fetchChunks(contactId: contact.id)
                allIMChunks.append(contentsOf: directChunks)
                existingChunkIds = Set(directChunks.map { $0.id })
                
                if contact.isCompany {
                    // For companies: also fetch iMessage chunks from all associated people
                    let associatedPeople = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                    for person in associatedPeople {
                        let personChunks = try await imessageRepository.fetchChunks(contactId: person.id)
                        let uniqueChunks = personChunks.filter { !existingChunkIds.contains($0.id) }
                        allIMChunks.append(contentsOf: uniqueChunks)
                        existingChunkIds.formUnion(uniqueChunks.map { $0.id })
                    }
                } else if let companyId = contact.companyId {
                    // For individuals: also include company's iMessage chunks
                    let companyChunks = try await imessageRepository.fetchChunks(contactId: companyId)
                    let uniqueChunks = companyChunks.filter { !existingChunkIds.contains($0.id) }
                    allIMChunks.append(contentsOf: uniqueChunks)
                }
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium
                dateFormatter.timeStyle = .none
                
                for chunk in allIMChunks {
                    let item = TimelineItem(
                        id: chunk.id,
                        type: .message,
                        title: "iMessage – \(dateFormatter.string(from: chunk.date)) (\(chunk.messageCount) messages)",
                        content: chunk.content,
                        date: chunk.date,
                        sourceId: chunk.id
                    )
                    items.append(item)
                }
                
                // Fetch emails and group by thread (non-critical, wrapped in separate try-catch)
                do {
                    var allEmails: [Email] = []
                    
                    // For companies: fetch emails for this company AND all associated people
                    if contact.isCompany {
                        // Fetch emails for the company contact itself
                        let companyEmails = try await emailRepository.fetchEmails(contactId: contact.id)
                        allEmails.append(contentsOf: companyEmails)
                        
                        // Fetch all people associated with this company
                        let associatedPeople = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                        
                        // Fetch emails for each associated person
                        for person in associatedPeople {
                            let personEmails = try await emailRepository.fetchEmails(contactId: person.id)
                            allEmails.append(contentsOf: personEmails)
                        }
                    } else {
                        // For individuals: just fetch their emails
                        allEmails = try await emailRepository.fetchEmails(contactId: contact.id)
                    }
                    
                    // Group emails by threadId
                    var threadGroups: [String: [Email]] = [:]
                    for email in allEmails {
                        let key = email.threadId ?? email.gmailId
                        if threadGroups[key] != nil {
                            threadGroups[key]?.append(email)
                        } else {
                            threadGroups[key] = [email]
                        }
                    }
                    
                    // Convert groups to TimelineEmailThread objects
                    var threads: [TimelineEmailThread] = []
                    for (threadId, emailsInThread) in threadGroups {
                        let thread = TimelineEmailThread(threadId: threadId, emails: emailsInThread)
                        threads.append(thread)
                    }
                    
                    // Sort threads by latest timestamp (newest first)
                    emailThreads = threads.sorted { $0.timestamp > $1.timestamp }
                    
                    // Note: We no longer add individual emails to timeline items
                    // They are displayed separately in the emailThreads section
                } catch {
                    print("ContactDetailViewModel: Failed to fetch emails: \(error)")
                    // Don't fail the whole timeline load for email errors
                    emailThreads = []
                }
                
                // Sort by date descending
                timelineItems = items.sorted { $0.date > $1.date }
                isLoading = false
                
            } catch {
                self.error = error
                isLoading = false
            }
        }
    }
    
    // MARK: - Load Associations
    
    func loadAssociations() {
        isLoadingAssociations = true
        
        Task {
            do {
                if contact.isCompany {
                    // For companies: fetch all people linked to this company
                    let people = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                    self.associatedPeople = people
                } else if let companyId = contact.companyId {
                    // For individuals: fetch the linked company
                    let company = try await contactRepository.fetchContact(id: companyId)
                    self.companyContact = company
                }
                
                isLoadingAssociations = false
            } catch {
                print("ContactDetailViewModel: Failed to load associations: \(error)")
                isLoadingAssociations = false
            }
        }
    }
    
    // MARK: - Add Comment
    
    func addComment(_ content: String) {
        Task {
            do {
                let comment = Comment(
                    id: UUID(),
                    contactId: contact.id,
                    content: content,
                    createdAt: Date(),
                    updatedAt: nil
                )
                
                _ = try await dailyRepository.createComment(comment)
                
                // Refresh timeline
                loadTimeline()
                
            } catch {
                self.error = error
            }
        }
    }
    
    // MARK: - Load Tasks
    
    func loadTasks() {
        isLoadingTasks = true
        
        Task {
            do {
                var allTasks: [AppTask] = []
                var existingIds: Set<UUID> = []
                
                // Fetch tasks for this contact
                let contactTasks = try await taskRepository.fetchTasks(contactId: contact.id)
                allTasks.append(contentsOf: contactTasks)
                existingIds = Set(contactTasks.map { $0.id })
                
                if contact.isCompany {
                    // For companies: also fetch tasks from all associated individuals
                    let associatedPeople = try await contactRepository.fetchContactsForCompany(companyId: contact.id)
                    for person in associatedPeople {
                        let personTasks = try await taskRepository.fetchTasks(contactId: person.id)
                        let uniqueTasks = personTasks.filter { !existingIds.contains($0.id) }
                        allTasks.append(contentsOf: uniqueTasks)
                        existingIds.formUnion(uniqueTasks.map { $0.id })
                    }
                } else if let companyId = contact.companyId {
                    // For individuals: also fetch their company's direct tasks
                    let companyTasks = try await taskRepository.fetchTasks(contactId: companyId)
                    let uniqueCompanyTasks = companyTasks.filter { !existingIds.contains($0.id) }
                    allTasks.append(contentsOf: uniqueCompanyTasks)
                }
                
                // Sort by creation date descending
                self.tasks = allTasks.sorted { $0.createdAt > $1.createdAt }
                isLoadingTasks = false
            } catch {
                self.error = error
                isLoadingTasks = false
            }
        }
    }
    
    // MARK: - Toggle Task Completion
    
    func toggleTaskCompletion(_ task: AppTask) {
        Task {
            do {
                var updated = try await taskRepository.toggleTaskCompletion(task)
                // Preserve transient properties that aren't returned from the database
                updated.contact = task.contact
                updated.contactName = task.contactName
                updated.contacts = task.contacts
                updated.recordingTypeName = task.recordingTypeName
                updated.recordingTime = task.recordingTime
                
                if let index = self.tasks.firstIndex(where: { $0.id == task.id }) {
                    self.tasks[index] = updated
                }
            } catch {
                self.error = error
            }
        }
    }
    
    // MARK: - iMessage Sync
    
    /// Sync iMessages for the current contact
    func syncIMessages() {
        guard canSyncIMessages else {
            syncResult = .error(message: "This contact has no phone number or email address.")
            return
        }
        
        // Check permission first
        if !IMessageSyncService.shared.checkAccess() {
            showPermissionAlert = true
            return
        }
        
        isSyncingMessages = true
        syncResult = nil
        
        Task {
            do {
                let count = try await imessageChunkManager.syncMessages(for: contact)
                
                if count > 0 {
                    syncResult = .success(count: count)
                    // Refresh timeline to show new messages
                    loadTimeline()
                } else {
                    syncResult = .success(count: 0)
                }
                
                isSyncingMessages = false
                
                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .success = syncResult {
                    syncResult = nil
                }
                
            } catch {
                if let imessageError = error as? IMessageError {
                    if case .noAccess = imessageError {
                        showPermissionAlert = true
                    } else {
                        syncResult = .error(message: imessageError.localizedDescription)
                    }
                } else {
                    syncResult = .error(message: error.localizedDescription)
                }
                isSyncingMessages = false
            }
        }
    }
    
    // MARK: - Email Sync
    
    /// Sync emails for the current contact
    func syncEmails() {
        guard contact.email != nil else {
            emailSyncResult = .error(message: "This contact has no email address.")
            return
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            emailSyncResult = .error(message: "Gmail is not connected. Please connect in Settings.")
            return
        }
        
        isSyncingEmails = true
        emailSyncResult = nil
        
        Task {
            do {
                let count = try await EmailSyncService.shared.syncEmails(for: contact)
                
                if count > 0 {
                    emailSyncResult = .success(count: count)
                    // Refresh timeline to show new emails
                    loadTimeline()
                } else {
                    emailSyncResult = .success(count: 0)
                }
                
                isSyncingEmails = false
                
                // Clear success message after 3 seconds
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                if case .success = emailSyncResult {
                    emailSyncResult = nil
                }
                
            } catch {
                emailSyncResult = .error(message: error.localizedDescription)
                isSyncingEmails = false
            }
        }
    }
    
    /// Open System Settings to Full Disk Access pane
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
    
    // MARK: - Reply to Email Thread
    
    /// Reply to a timeline email thread
    func replyToTimelineThread(_ thread: TimelineEmailThread, body: String) async throws {
        let latestEmail = thread.latestEmail
        
        // Determine the recipient email - if the latest was inbound, reply to sender, otherwise use same recipient
        let recipientEmail: String
        if latestEmail.direction == .inbound {
            recipientEmail = latestEmail.senderEmail ?? ""
        } else {
            recipientEmail = latestEmail.recipientEmail ?? latestEmail.senderEmail ?? ""
        }
        
        guard !recipientEmail.isEmpty else {
            throw ReplyError.noRecipientEmail
        }
        
        guard GmailAuthService.shared.isAuthenticated else {
            throw ReplyError.notAuthenticated
        }
        
        // Build subject with Re: prefix if not already present
        let subject: String
        if !thread.subject.lowercased().hasPrefix("re:") && thread.subject != "(No Subject)" {
            subject = "Re: \(thread.subject)"
        } else {
            subject = thread.subject
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
            replyToMessageId: latestEmail.gmailId,
            threadId: thread.id
        )
        
        // Create Email model and save to Supabase
        let email = Email(
            contactId: contact.id,
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
        print("ContactDetailViewModel: Reply sent and saved with ID \(savedEmail.id)")
        
        // Refresh timeline to show the new message
        loadTimeline()
    }
    
    // MARK: - Label Management
    
    /// Load labels for the current contact and all available labels
    func loadLabels() {
        isLoadingLabels = true
        
        Task {
            do {
                // Fetch all available labels
                let all = try await labelRepository.fetchAllLabels()
                self.allLabels = all
                
                // Fetch labels assigned to this contact
                let assigned = try await labelRepository.fetchLabelsForContact(contactId: contact.id)
                self.labels = assigned
                
                isLoadingLabels = false
            } catch {
                print("ContactDetailViewModel: Failed to load labels: \(error)")
                isLoadingLabels = false
            }
        }
    }
    
    /// Assign a label to the current contact and propagate to related entities
    func assignLabel(_ label: ContactLabel) {
        Task {
            do {
                // Assign label to contact
                try await labelRepository.assignLabel(labelId: label.id, contactId: contact.id)
                
                // Propagate to related entities (company ↔ contacts)
                try await labelRepository.propagateLabelAssignment(
                    label: label,
                    contact: contact,
                    contactRepository: contactRepository
                )
                
                // Update local state
                if !labels.contains(where: { $0.id == label.id }) {
                    labels.append(label)
                    labels.sort(by: { $0.name < $1.name })
                }
                
                print("ContactDetailViewModel: Assigned label '\(label.name)' to contact '\(contact.name)'")
                
                // Notify contacts list to refresh labels
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            } catch {
                print("ContactDetailViewModel: Failed to assign label: \(error)")
                self.error = error
            }
        }
    }
    
    /// Remove a label from the current contact (does not propagate removal)
    func removeLabel(_ label: ContactLabel) {
        Task {
            do {
                try await labelRepository.removeLabel(labelId: label.id, contactId: contact.id)
                
                // Update local state
                labels.removeAll { $0.id == label.id }
                
                print("ContactDetailViewModel: Removed label '\(label.name)' from contact '\(contact.name)'")
                
                // Notify contacts list to refresh labels
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            } catch {
                print("ContactDetailViewModel: Failed to remove label: \(error)")
                self.error = error
            }
        }
    }
    
    /// Create a new label and optionally assign it to the current contact
    func createLabel(name: String, color: String, assignToContact: Bool = true) {
        Task {
            do {
                let newLabel = ContactLabel(name: name, color: color)
                let savedLabel = try await labelRepository.createLabel(newLabel)
                
                // Add to all available labels
                allLabels.append(savedLabel)
                allLabels.sort(by: { $0.name < $1.name })
                
                // Optionally assign to current contact
                if assignToContact {
                    assignLabel(savedLabel)
                }
                
                print("ContactDetailViewModel: Created label '\(savedLabel.name)' with color \(savedLabel.color)")
            } catch {
                print("ContactDetailViewModel: Failed to create label: \(error)")
                self.error = error
            }
        }
    }
    
    /// Create a new label asynchronously - throws on error so caller can handle it
    func createLabelAsync(name: String, color: String, assignToContact: Bool = true) async throws -> ContactLabel {
        let newLabel = ContactLabel(name: name, color: color)
        let savedLabel = try await labelRepository.createLabel(newLabel)
        
        // Add to all available labels on main actor
        await MainActor.run {
            allLabels.append(savedLabel)
            allLabels.sort(by: { $0.name < $1.name })
        }
        
        // Optionally assign to current contact
        if assignToContact {
            try await labelRepository.assignLabel(labelId: savedLabel.id, contactId: contact.id)
            
            // Propagate to related entities
            try await labelRepository.propagateLabelAssignment(
                label: savedLabel,
                contact: contact,
                contactRepository: contactRepository
            )
            
            // Update local state
            await MainActor.run {
                if !labels.contains(where: { $0.id == savedLabel.id }) {
                    labels.append(savedLabel)
                    labels.sort(by: { $0.name < $1.name })
                }
                
                // Notify contacts list to refresh labels
                NotificationCenter.default.post(name: .contactsDidChange, object: nil)
            }
        }
        
        print("ContactDetailViewModel: Created label '\(savedLabel.name)' with color \(savedLabel.color)")
        return savedLabel
    }
    
    /// Update an existing label's name or color
    func updateLabel(_ label: ContactLabel) {
        Task {
            do {
                let updatedLabel = try await labelRepository.updateLabel(label)
                
                // Update in all labels list
                if let index = allLabels.firstIndex(where: { $0.id == label.id }) {
                    allLabels[index] = updatedLabel
                }
                
                // Update in assigned labels if present
                if let index = labels.firstIndex(where: { $0.id == label.id }) {
                    labels[index] = updatedLabel
                }
                
                print("ContactDetailViewModel: Updated label '\(updatedLabel.name)'")
            } catch {
                print("ContactDetailViewModel: Failed to update label: \(error)")
                self.error = error
            }
        }
    }
    
    /// Delete a label entirely (removes from all contacts)
    func deleteLabel(_ label: ContactLabel) {
        Task {
            do {
                try await labelRepository.deleteLabel(id: label.id)
                
                // Remove from all labels list
                allLabels.removeAll { $0.id == label.id }
                
                // Remove from assigned labels
                labels.removeAll { $0.id == label.id }
                
                print("ContactDetailViewModel: Deleted label '\(label.name)'")
            } catch {
                print("ContactDetailViewModel: Failed to delete label: \(error)")
                self.error = error
            }
        }
    }
    
    /// Check if a label is assigned to the current contact
    func isLabelAssigned(_ label: ContactLabel) -> Bool {
        labels.contains { $0.id == label.id }
    }
    
    /// Toggle label assignment for the current contact
    func toggleLabel(_ label: ContactLabel) {
        if isLabelAssigned(label) {
            removeLabel(label)
        } else {
            assignLabel(label)
        }
    }
}


