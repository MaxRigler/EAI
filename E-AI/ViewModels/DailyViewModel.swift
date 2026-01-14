// DailyViewModel.swift
// Daily summary management

import Foundation

@MainActor
class DailyViewModel: ObservableObject {
    @Published var selectedDate = Date()
    @Published var recordings: [Recording] = []
    @Published var dailySummary: DailySummary?
    @Published var isLoading = false
    @Published var isGeneratingSummary = false
    @Published var error: Error?
    
    private let dailyRepository = DailyRepository()
    private let recordingRepository = RecordingRepository()
    
    func loadDay() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                async let summaryTask = dailyRepository.fetchDailySummary(for: selectedDate)
                async let recordingsTask = recordingRepository.fetchRecordings(for: selectedDate)
                
                self.dailySummary = try await summaryTask
                var fetchedRecordings = try await recordingsTask
                
                // Enrich recordings with related data
                fetchedRecordings = await enrichRecordings(fetchedRecordings)
                
                self.recordings = fetchedRecordings
            } catch {
                self.error = error
                print("DailyViewModel: Failed to load daily data: \(error)")
            }
            self.isLoading = false
        }
    }
    
    /// Enrich recordings with recording type name, summary preview, and contact names
    /// Uses batch queries to minimize database round-trips
    private func enrichRecordings(_ recordings: [Recording]) async -> [Recording] {
        guard !recordings.isEmpty else { return [] }
        guard let client = await SupabaseManager.shared.getClient() else { return recordings }
        
        let recordingIds = recordings.map { $0.id.uuidString.lowercased() }
        
        // Batch fetch all recording types (usually just a few types)
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
            
            // Collect company IDs that need to be fetched
            let companyIds = Set(allContacts.compactMap { $0.companyId }).map { $0.uuidString.lowercased() }
            
            // Batch fetch all company contacts that aren't already in the map
            if !companyIds.isEmpty {
                let companyContacts: [CRMContact] = (try? await client
                    .from("crm_contacts")
                    .select()
                    .in("id", values: companyIds)
                    .execute()
                    .value) ?? []
                
                // Create a map of company contacts
                let companyMap = Dictionary(uniqueKeysWithValues: companyContacts.map { ($0.id, $0) })
                
                // Attach company contacts to their associated contacts
                for (id, var contact) in contactMap {
                    if let companyId = contact.companyId, let company = companyMap[companyId] {
                        contact.companyContact = company
                        contactMap[id] = contact
                    }
                }
            }
        }
        
        // Now enrich each recording using the pre-fetched data
        var enriched: [Recording] = []
        
        for var recording in recordings {
            // Set recording type name
            if let typeId = recording.recordingTypeId,
               let recordingType = recordingTypeMap[typeId] {
                recording.recordingTypeName = recordingType.name
            }
            
            // Set summary
            if let summary = summaryMap[recording.id] {
                let preview = String(summary.summaryText.prefix(100))
                recording.summaryPreview = preview.count == 100 ? preview + "..." : preview
                recording.fullSummary = summary.summaryText
            }
            
            // Set contacts from speakers
            let speakers = speakersByRecording[recording.id] ?? []
            var contactNames: [String] = []
            var contacts: [CRMContact] = []
            
            for speaker in speakers {
                if let contactId = speaker.contactId,
                   let contact = contactMap[contactId] {
                    contactNames.append(contact.name)
                    contacts.append(contact)
                }
            }
            
            recording.contactNames = contactNames
            recording.contacts = contacts
            
            enriched.append(recording)
        }
        
        print("DailyViewModel: Batch enriched \(enriched.count) recordings")
        return enriched
    }
    
    /// Generate a daily summary for the selected date
    func generateDailySummary() {
        guard !isGeneratingSummary else { return }
        isGeneratingSummary = true
        
        Task {
            do {
                let summary = try await DailySummaryService.shared.generateDailySummary(for: selectedDate)
                self.dailySummary = summary
                print("DailyViewModel: Generated summary with \(summary.recordingCount) recordings")
            } catch {
                self.error = error
                print("DailyViewModel: Failed to generate summary: \(error)")
            }
            self.isGeneratingSummary = false
        }
    }
    
    func goToPreviousDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
        loadDay()
    }
    
    func goToNextDay() {
        selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
        loadDay()
    }
    
    func goToToday() {
        selectedDate = Date()
        loadDay()
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }
}
