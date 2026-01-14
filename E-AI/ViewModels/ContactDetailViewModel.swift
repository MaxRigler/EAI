// ContactDetailViewModel.swift
// Contact detail and timeline state

import Foundation
import AppKit

@MainActor
class ContactDetailViewModel: ObservableObject {
    
    // MARK: - Properties
    
    @Published var contact: CRMContact
    @Published var isSaving = false
    
    @Published var timelineItems: [TimelineItem] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    // Tasks properties
    @Published var tasks: [AppTask] = []
    @Published var selectedTaskFilter: TaskFilter = .open
    @Published var isLoadingTasks = false
    
    // iMessage sync properties
    @Published var isSyncingMessages = false
    @Published var syncResult: SyncResult?
    @Published var showPermissionAlert = false
    
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
    
    // MARK: - Private Properties
    
    private let recordingRepository = RecordingRepository()
    private let dailyRepository = DailyRepository()
    private let taskRepository = TaskRepository()
    private let contactRepository = ContactRepository()
    private let contactsManager = ContactsManager.shared
    private let imessageChunkManager = IMessageChunkManager.shared
    private let imessageRepository = IMessageRepository()
    
    // MARK: - Initialization
    
    init(contact: CRMContact) {
        self.contact = contact
    }
    
    // MARK: - Save Contact (Two-Way Sync)
    
    func saveContact(_ updatedContact: CRMContact) {
        isSaving = true
        
        Task {
            do {
                // 1. Update in Supabase
                let savedContact = try await contactRepository.updateContact(updatedContact)
                
                // 2. Update local state immediately (Supabase succeeded)
                self.contact = savedContact
                
                // 3. If linked to Apple Contacts AND authorized, update there too
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
                
                isSaving = false
                
            } catch {
                self.error = error
                isSaving = false
            }
        }
    }
    
    // MARK: - Load Timeline
    
    func loadTimeline() {
        isLoading = true
        
        Task {
            do {
                var items: [TimelineItem] = []
                
                // Fetch recordings for this contact
                let recordings = try await recordingRepository.fetchRecordings(contactId: contact.id)
                
                for recording in recordings {
                    // Fetch summary for each recording
                    let summary = try await recordingRepository.fetchSummary(recordingId: recording.id)
                    
                    let item = TimelineItem(
                        id: recording.id,
                        type: .recording,
                        title: recording.recordingTypeName ?? "Call",
                        content: summary?.summaryText ?? "Processing...",
                        date: recording.createdAt,
                        sourceId: recording.id
                    )
                    items.append(item)
                }
                
                // Fetch comments
                let comments = try await dailyRepository.fetchComments(contactId: contact.id)
                
                for comment in comments {
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
                
                // Fetch iMessage chunks
                let imessageChunks = try await imessageRepository.fetchChunks(contactId: contact.id)
                
                for chunk in imessageChunks {
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    dateFormatter.timeStyle = .none
                    
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
                
                // Sort by date descending
                timelineItems = items.sorted { $0.date > $1.date }
                isLoading = false
                
            } catch {
                self.error = error
                isLoading = false
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
                let contactTasks = try await taskRepository.fetchTasks(contactId: contact.id)
                self.tasks = contactTasks
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
    
    /// Open System Settings to Full Disk Access pane
    func openFullDiskAccessSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}

