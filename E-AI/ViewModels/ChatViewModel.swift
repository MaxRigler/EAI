// ChatViewModel.swift
// Chat threads and messages management

import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var selectedThread: ChatThread?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: Error?
    
    private let repository = ChatRepository()
    
    func loadThreads() {
        guard !isLoading else { return }
        isLoading = true
        
        Task {
            do {
                let allThreads = try await repository.fetchAllThreads()
                self.threads = allThreads
                print("Loaded \(allThreads.count) chat threads")
            } catch {
                self.error = error
                print("Failed to load threads: \(error)")
            }
            self.isLoading = false
        }
    }
    
    func selectThread(_ thread: ChatThread) {
        selectedThread = thread
        loadMessages(for: thread)
    }
    
    func loadMessages(for thread: ChatThread) {
        Task {
            do {
                let threadMessages = try await repository.fetchMessages(threadId: thread.id)
                self.messages = threadMessages
            } catch {
                self.error = error
            }
        }
    }
    
    func sendMessage(_ content: String) {
        guard let thread = selectedThread else { return }
        guard !isSending else { return }
        
        isSending = true
        
        Task {
            do {
                // Create user message
                let userMessage = ChatMessage(
                    id: UUID(),
                    threadId: thread.id,
                    role: .user,
                    content: content,
                    createdAt: Date()
                )
                let savedUserMsg = try await repository.createMessage(userMessage)
                self.messages.append(savedUserMsg)
                
                // TODO: Call AI API for response
                // For now, create a placeholder response
                let assistantMessage = ChatMessage(
                    id: UUID(),
                    threadId: thread.id,
                    role: .assistant,
                    content: "AI response coming soon...",
                    createdAt: Date()
                )
                let savedAsstMsg = try await repository.createMessage(assistantMessage)
                self.messages.append(savedAsstMsg)
                
            } catch {
                self.error = error
            }
            self.isSending = false
        }
    }
    
    func createNewThread() {
        Task {
            do {
                let newThread = ChatThread(
                    id: UUID(),
                    title: "New Chat",
                    createdAt: Date(),
                    updatedAt: Date()
                )
                let created = try await repository.createThread(newThread)
                self.threads.insert(created, at: 0)
                self.selectThread(created)
            } catch {
                self.error = error
            }
        }
    }
}
