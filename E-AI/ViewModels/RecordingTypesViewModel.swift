// RecordingTypesViewModel.swift
// Recording type picker management

import Foundation

@MainActor
class RecordingTypesViewModel: ObservableObject {
    @Published var recordingTypes: [RecordingType] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository = DailyRepository()
    
    func loadRecordingTypes() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let types = try await repository.fetchRecordingTypes()
                self.recordingTypes = types
                print("Loaded \(types.count) recording types")
            } catch {
                self.error = error
                print("Failed to load recording types: \(error)")
            }
            self.isLoading = false
        }
    }
}
