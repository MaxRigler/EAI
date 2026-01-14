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
                let allTasks = try await repository.fetchAllTasks()
                self.tasks = allTasks
                print("Loaded \(allTasks.count) tasks")
            } catch {
                self.error = error
                print("Failed to load tasks: \(error)")
            }
            self.isLoading = false
        }
    }
    
    func toggleCompletion(_ task: AppTask) {
        Task {
            do {
                var updated = try await repository.toggleTaskCompletion(task)
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
