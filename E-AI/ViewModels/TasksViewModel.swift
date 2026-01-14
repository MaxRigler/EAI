// TasksViewModel.swift
// Tasks list management

import Foundation

@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [AppTask] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var filter: TaskFilter = .all
    
    private let repository = TaskRepository()
    
    enum TaskFilter {
        case all, open, completed
    }
    
    var filteredTasks: [AppTask] {
        switch filter {
        case .all:
            return tasks
        case .open:
            return tasks.filter { $0.status == .open }
        case .completed:
            return tasks.filter { $0.status == .completed }
        }
    }
    
    func loadTasks() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                var allTasks = try await repository.fetchAllTasks()
                
                // Enrich tasks with all contacts from their recordings
                allTasks = await enrichTasksWithRecordingContacts(allTasks)
                
                self.tasks = allTasks
                print("Loaded \(allTasks.count) tasks")
            } catch {
                self.error = error
                print("Failed to load tasks: \(error)")
            }
            self.isLoading = false
        }
    }
    
    /// Enrich tasks with all contacts from their associated recordings
    private func enrichTasksWithRecordingContacts(_ tasks: [AppTask]) async -> [AppTask] {
        guard !tasks.isEmpty else { return [] }
        guard let client = await SupabaseManager.shared.getClient() else { return tasks }
        
        // Get all recording IDs that have tasks
        let recordingIds = Set(tasks.compactMap { $0.recordingId }).map { $0.uuidString.lowercased() }
        guard !recordingIds.isEmpty else { return tasks }
        
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
        
        // Enrich each task with contacts from its recording
        var enriched: [AppTask] = []
        for var task in tasks {
            if let recordingId = task.recordingId {
                let speakers = speakersByRecording[recordingId] ?? []
                var recordingContacts: [CRMContact] = []
                for speaker in speakers {
                    if let contactId = speaker.contactId,
                       let speakerContact = contactMap[contactId] {
                        recordingContacts.append(speakerContact)
                    }
                }
                task.contacts = recordingContacts
            }
            enriched.append(task)
        }
        
        return enriched
    }
    
    func toggleCompletion(_ task: AppTask) {
        Task {
            do {
                var updated = try await repository.toggleTaskCompletion(task)
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
    
    func deleteTask(_ task: AppTask) {
        Task {
            do {
                try await repository.deleteTask(id: task.id)
                self.tasks.removeAll { $0.id == task.id }
            } catch {
                self.error = error
            }
        }
    }
}
