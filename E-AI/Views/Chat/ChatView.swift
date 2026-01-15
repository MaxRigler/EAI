// ChatView.swift
// Claude-style conversational interface for querying CRM data

import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var messageText = ""
    @State private var showSidebar = true
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (thread list)
            if showSidebar {
                sidebar
                    .frame(width: 100)
                
                Divider()
            }
            
            // Main chat area
            mainChatArea
        }
    }
    
    // MARK: - Sidebar
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            // New chat button
            Button(action: { viewModel.createNewThread() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("New")
                }
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.accentColor.opacity(0.1))
            
            Divider()
            
            // Thread list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.threads) { thread in
                        ThreadRow(
                            thread: thread,
                            isSelected: viewModel.selectedThread?.id == thread.id,
                            onSelect: { viewModel.selectThread(thread) }
                        )
                    }
                }
                .padding(8)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Main Chat Area
    
    private var mainChatArea: some View {
        VStack(spacing: 0) {
            // Chat header
            chatHeader
            
            Divider()
            
            // Messages
            if let thread = viewModel.selectedThread {
                messagesView
            } else {
                emptyState
            }
            
            Divider()
            
            // Input field
            inputField
        }
    }
    
    // MARK: - Chat Header
    
    private var chatHeader: some View {
        HStack {
            Button(action: { showSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(viewModel.selectedThread?.title ?? "New Chat")
                .font(.headline)
            
            Spacer()
            
            // Placeholder for balance
            Image(systemName: "sidebar.left")
                .foregroundColor(.clear)
        }
        .padding()
    }
    
    // MARK: - Messages View
    
    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }
                    
                    if viewModel.isSending {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Thinking...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .id("loading")
                    }
                    
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button("Dismiss") {
                                viewModel.dismissError()
                            }
                            .font(.caption)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.isSending) { sending in
                if sending {
                    withAnimation {
                        proxy.scrollTo("loading", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            withAnimation {
                proxy.scrollTo(lastMessage.id, anchor: .bottom)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("Ask your Second Brain")
                .font(.headline)
            
            Text("Query your contacts, recordings, and transcripts using natural language.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Example queries
            VStack(spacing: 8) {
                exampleQuery("Who mentioned budget concerns?")
                exampleQuery("Summarize my calls with John")
                exampleQuery("What tasks are due this week?")
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            // Allow tapping empty state to dismiss focus, but don't block
        }
    }
    
    private func exampleQuery(_ text: String) -> some View {
        Button(action: {
            messageText = text
            sendMessage()
        }) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.1))
                .foregroundColor(.accentColor)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Input Field
    
    private var inputField: some View {
        HStack(spacing: 12) {
            NativeTextField(
                text: $messageText,
                placeholder: "Ask anything...",
                isDisabled: viewModel.isSending,
                onSubmit: sendMessage
            )
            .frame(height: 24)
            
            if viewModel.isSending {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(messageText.isEmpty ? .secondary : .accentColor)
                }
                .buttonStyle(.plain)
                .disabled(messageText.isEmpty)
            }
        }
        .padding()
    }
    
    private func sendMessage() {
        guard !messageText.isEmpty else { return }
        let text = messageText
        messageText = ""
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: ChatThread
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.title)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(2)
                
                Text(thread.updatedAt.relativeFormatted)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
            }
            
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .font(.body)
                    .padding(12)
                    .background(message.role == .user ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(message.role == .user ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.createdAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if message.role == .assistant {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Native macOS TextField

/// Native NSTextField wrapper for reliable text input on macOS
struct NativeTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isDisabled: Bool
    var onSubmit: () -> Void
    
    func makeNSView(context: Context) -> NSTextField {
        let textField = NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.isBordered = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.font = .systemFont(ofSize: 14)
        textField.focusRingType = .exterior
        textField.isEditable = !isDisabled
        textField.isSelectable = true
        return textField
    }
    
    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        nsView.placeholderString = placeholder
        nsView.isEditable = !isDisabled
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: NativeTextField
        
        init(_ parent: NativeTextField) {
            self.parent = parent
        }
        
        func controlTextDidChange(_ obj: Notification) {
            if let textField = obj.object as? NSTextField {
                parent.text = textField.stringValue
            }
        }
        
        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }
}

#Preview {
    ChatView()
        .frame(width: 390, height: 700)
}
