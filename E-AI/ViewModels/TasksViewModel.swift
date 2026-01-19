// TasksViewModel.swift
// Tasks list management with local caching for offline resilience

import Foundation

@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [AppTask] = []
    @Published var isLoading = false
    @Published var error: Error?
    @Published var loadError: String?
    @Published var filter: TaskFilter = .all
    @Published var isOfflineMode = false
    @Published var lastSyncedAt: Date?
    @Published var skippedTaskCount = 0
    
    private let repository = TaskRepository()
    private var hasAttemptedLoad = false
    
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
        loadError = nil
        skippedTaskCount = 0
        
        Task {
            // Phase 1: Wait for Supabase to be initialized (up to 5 seconds)
            loadError = "Connecting to database..."
            let initialized = await SupabaseManager.shared.waitForInitialization(timeoutSeconds: 5.0)
            
            if !initialized {
                print("⚠️ TasksViewModel: Supabase initialization timeout, attempting fetch anyway...")
            }
            
            // Phase 2: Fetch with exponential backoff retries
            var allTasks: [AppTask] = []
            var lastError: Error?
            let retryDelays: [UInt64] = [0, 500_000_000, 1_000_000_000, 2_000_000_000]  // 0, 0.5s, 1s, 2s
            
            for (attempt, delay) in retryDelays.enumerated() {
                if delay > 0 {
                    loadError = "Retrying... (attempt \(attempt + 1)/\(retryDelays.count))"
                    try? await Task.sleep(nanoseconds: delay)
                }
                
                do {
                    allTasks = try await repository.fetchAllTasks()
                    
                    // If we got tasks OR Supabase is confirmed initialized (empty is valid), we're done
                    let isInitialized = await SupabaseManager.shared.isInitialized
                    if !allTasks.isEmpty || isInitialized {
                        lastError = nil
                        break
                    }
                } catch {
                    lastError = error
                    print("❌ TasksViewModel: Fetch attempt \(attempt + 1) failed: \(error)")
                }
            }
            
            hasAttemptedLoad = true
            
            // Phase 3: Process results or fall back to cache
            if lastError == nil {
                // Success - enrich and display tasks
                allTasks = await enrichTasksWithRecordingContacts(allTasks)
                
                self.tasks = allTasks
                self.loadError = nil
                self.isOfflineMode = false
                self.lastSyncedAt = Date()
                
                // Cache tasks locally for offline resilience
                await TaskCacheService.shared.cacheTasks(allTasks)
                
                print("✅ TasksViewModel: Loaded \(allTasks.count) tasks from remote")
            } else {
                print("❌ TasksViewModel: All fetch attempts failed")
                
                // Try to load from local cache
                if let cached = await TaskCacheService.shared.loadCachedTasks() {
                    self.tasks = cached.tasks
                    self.isOfflineMode = true
                    self.lastSyncedAt = cached.metadata?.lastSyncedAt
                    self.loadError = nil
                    print("📦 TasksViewModel: Loaded \(cached.tasks.count) tasks from cache (offline mode)")
                } else {
                    self.error = lastError
                    self.loadError = "Failed to load tasks"
                    print("❌ TasksViewModel: No cached tasks available")
                }
            }
            
            self.isLoading = false
        }
    }
    
    /// Force refresh from remote, ignoring cache
    func forceRefresh() {
        hasAttemptedLoad = false
        loadTasks()
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
                
                // Update cache with modified tasks
                await TaskCacheService.shared.cacheTasks(self.tasks)
            } catch {
                self.error = error
            }
        }
    }
    
    /// Soft delete a task (marks as deleted instead of permanent deletion)
    func deleteTask(_ task: AppTask) {
        Task {
            do {
                try await repository.softDeleteTask(id: task.id)
                self.tasks.removeAll { $0.id == task.id }
                
                // Update cache with modified tasks
                await TaskCacheService.shared.cacheTasks(self.tasks)
                
                print("🗑️ TasksViewModel: Soft-deleted task \(task.id)")
            } catch {
                self.error = error
                print("❌ TasksViewModel: Failed to delete task: \(error)")
            }
        }
    }
}

