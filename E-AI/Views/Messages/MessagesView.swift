// MessagesView.swift
// Main view for the Messages tab displaying email threads

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @ObservedObject private var navigationState = AppNavigationState.shared
    @State private var expandedThreadId: String?
    @State private var threadToArchive: EmailThread?
    @State private var showArchiveConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Filter picker
            filterPicker
            
            // Search bar
            searchBar
            
            // Content
            if viewModel.isLoading {
                loadingState
            } else if viewModel.filteredThreads.isEmpty {
                emptyState
            } else {
                threadsList
            }
        }
        .onAppear {
            viewModel.checkDueReminders()
            viewModel.loadThreads()
        }
        .alert("Archive Message?", isPresented: $showArchiveConfirmation, presenting: threadToArchive) { thread in
            Button("Cancel", role: .cancel) {
                threadToArchive = nil
            }
            Button(viewModel.currentFilter == .archived ? "Unarchive" : "Archive", role: viewModel.currentFilter == .archived ? nil : .destructive) {
                Task {
                    if viewModel.currentFilter == .archived {
                        await viewModel.unarchiveThread(thread)
                    } else {
                        await viewModel.archiveThread(thread)
                    }
                    threadToArchive = nil
                }
            }
        } message: { thread in
            if viewModel.currentFilter == .archived {
                Text("Move this conversation back to active messages?")
            } else {
                Text("This will move the conversation to your archived messages.")
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Messages")
                .font(.headline)
            
            Spacer()
            
            // Sync emails button
            if viewModel.isSyncing {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(width: 14, height: 14)
            } else {
                Button(action: { 
                    Task {
                        await viewModel.syncEmails()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Sync emails from Gmail")
            }
        }
        .padding()
    }
    
    // MARK: - Filter Picker
    
    private var filterPicker: some View {
        VStack(spacing: 8) {
            Picker("Filter", selection: $viewModel.currentFilter) {
                ForEach(MessageFilter.allCases, id: \.self) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Sub-filter for archived messages
            if viewModel.currentFilter == .archived {
                Picker("", selection: $viewModel.archivedSubFilter) {
                    ForEach(ArchivedSubFilter.allCases, id: \.self) { subFilter in
                        Text(subFilter.rawValue).tag(subFilter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 32)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Search Bar
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search messages...", text: $viewModel.searchText)
                .textFieldStyle(.plain)
            
            if !viewModel.searchText.isEmpty {
                Button(action: { viewModel.searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading State
    
    private var loadingState: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading messages...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: viewModel.currentFilter == .archived ? "archivebox" : "envelope.badge")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text(viewModel.currentFilter == .archived ? "No Archived Messages" : "No Messages Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(viewModel.currentFilter == .archived 
                 ? "Archived messages will appear here."
                 : "Email threads from your synced contacts will appear here.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if viewModel.error != nil {
                Button(action: { viewModel.refresh() }) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Threads List
    
    private var threadsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredThreads) { thread in
                    EmailThreadRow(
                        thread: thread,
                        isExpanded: expandedThreadId == thread.id,
                        isArchived: viewModel.currentFilter == .archived,
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedThreadId == thread.id {
                                    expandedThreadId = nil
                                } else {
                                    expandedThreadId = thread.id
                                }
                            }
                        },
                        onArchive: {
                            threadToArchive = thread
                            showArchiveConfirmation = true
                        },
                        onRemind: { date in
                            Task {
                                await viewModel.snoozeThread(thread, until: date)
                            }
                        },
                        onReply: { replyText in
                            try await viewModel.replyToThread(thread, body: replyText)
                        },
                        onCompanyTap: { company in
                            // Navigate to company contact in Contacts tab
                            navigationState.selectedTab = .contacts
                            navigationState.selectedContact = company
                        }
                    )
                }
            }
            .padding()
        }
    }
}

#Preview {
    MessagesView()
        .frame(width: 390, height: 700)
}
