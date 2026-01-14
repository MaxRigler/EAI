// TasksView.swift
// Auto-extracted and manually created tasks

import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var selectedFilter: TaskFilter = .open
    
    enum TaskFilter: String, CaseIterable {
        case all = "All"
        case open = "Open"
        case completed = "Completed"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter tabs
            filterTabs
            
            Divider()
            
            // Task list
            if viewModel.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .onAppear {
            viewModel.loadTasks()
        }
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        HStack(spacing: 0) {
            ForEach(TaskFilter.allCases, id: \.self) { filter in
                Button(action: { selectedFilter = filter }) {
                    VStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                        
                        Rectangle()
                            .fill(selectedFilter == filter ? Color.accentColor : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Task List
    
    private var taskList: some View {
        List {
            ForEach(filteredTasks) { task in
                TaskRow(task: task, onToggle: {
                    viewModel.toggleCompletion(task)
                })
            }
        }
        .listStyle(.plain)
    }
    
    private var filteredTasks: [AppTask] {
        switch selectedFilter {
        case .all:
            return viewModel.tasks
        case .open:
            return viewModel.tasks.filter { $0.status == .open }
        case .completed:
            return viewModel.tasks.filter { $0.status == .completed }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(emptyStateTitle)
                .font(.headline)
            
            Text(emptyStateMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateTitle: String {
        switch selectedFilter {
        case .all: return "No Tasks"
        case .open: return "All Caught Up!"
        case .completed: return "No Completed Tasks"
        }
    }
    
    private var emptyStateMessage: String {
        switch selectedFilter {
        case .all: return "Tasks will appear here as they're extracted from your recordings."
        case .open: return "You have no open tasks. Great job!"
        case .completed: return "Complete some tasks to see them here."
        }
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: AppTask
    let onToggle: () -> Void
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(task.status == .completed ? .green : .secondary)
            }
            .buttonStyle(.plain)
            
            // Task details
            VStack(alignment: .leading, spacing: 6) {
                Text(task.description)
                    .font(.body)
                    .strikethrough(task.status == .completed)
                    .foregroundColor(task.status == .completed ? .secondary : .primary)
                
                // Contact and call context row
                if !task.contacts.isEmpty || task.contact != nil || task.recordingTypeName != nil {
                    HStack(spacing: 8) {
                        // Show all contacts from the recording
                        if !task.contacts.isEmpty {
                            ForEach(task.contacts, id: \.id) { contact in
                                Button(action: {
                                    AppNavigationState.shared.navigateToContact(contact)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: contact.isCompany ? "building.2.fill" : "person.fill")
                                            .font(.caption2)
                                        Text(contact.name)
                                    }
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        } else if let contact = task.contact {
                            // Fallback to single contact if no enriched contacts
                            Button(action: {
                                AppNavigationState.shared.navigateToContact(contact)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.caption2)
                                    Text(contact.name)
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Call context: Recording type + time
                        if let recordingTypeName = task.recordingTypeName {
                            HStack(spacing: 4) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(recordingTypeName)
                                if let recordingTime = task.recordingTime {
                                    Text("•")
                                    Text(recordingTime.formatted(date: .omitted, time: .shortened))
                                }
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Second metadata row: due date and auto-extracted badge
                HStack(spacing: 8) {
                    // Due date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(dueDate.formatted(date: .abbreviated, time: .omitted))
                        }
                        .font(.caption)
                        .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                    }
                    
                    // Source indicator
                    if task.recordingId != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.caption2)
                            Text("Auto-extracted")
                        }
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 8)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && task.status == .open
    }
}

#Preview {
    TasksView()
        .frame(width: 390, height: 700)
}
