// MessagesView.swift
// Main view for the Messages tab displaying email threads

import SwiftUI

struct MessagesView: View {
    @StateObject private var viewModel = MessagesViewModel()
    @State private var expandedThreadId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
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
            viewModel.loadThreads()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Text("Messages")
                .font(.headline)
            
            Spacer()
            
            // Refresh button
            Button(action: { viewModel.refresh() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Refresh messages")
        }
        .padding()
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
            
            Image(systemName: "envelope.badge")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("No Messages Yet")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Email threads from your synced contacts will appear here.")
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
                        onTap: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if expandedThreadId == thread.id {
                                    expandedThreadId = nil
                                } else {
                                    expandedThreadId = thread.id
                                }
                            }
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
