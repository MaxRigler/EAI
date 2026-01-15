// ChatViewModel.swift
// Chat threads and messages management with RAG-powered responses

import Foundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var selectedThread: ChatThread?
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var error: Error?
    @Published var errorMessage: String?
    
    private let repository = ChatRepository()
    private let ragService = RAGSearchService.shared
    
    init() {
        // Load threads on init
        loadThreads()
    }
    
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
    
    func sendMessage(_ content: String) async {
        guard let thread = selectedThread else {
            // Create new thread if none selected
            await createNewThreadAndSend(content)
            return
        }
        
        guard !isSending else { return }
        
        isSending = true
        errorMessage = nil
        
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
            
            // Update thread title if this is the first message
            if messages.count == 1 {
                let title = generateThreadTitle(from: content)
                try await repository.updateThreadTitle(id: thread.id, title: title)
                // Update local thread
                if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                    var updatedThread = threads[index]
                    updatedThread.title = title
                    threads[index] = updatedThread
                    selectedThread = updatedThread
                }
            }
            
            // Update thread timestamp
            try await repository.updateThreadTimestamp(id: thread.id)
            
            // Generate RAG-powered response
            let aiResponse = try await ragService.generateResponse(
                query: content,
                conversationHistory: Array(messages.dropLast()) // Exclude the message we just added
            )
            
            // Create assistant message
            let assistantMessage = ChatMessage(
                id: UUID(),
                threadId: thread.id,
                role: .assistant,
                content: aiResponse,
                createdAt: Date()
            )
            let savedAsstMsg = try await repository.createMessage(assistantMessage)
            self.messages.append(savedAsstMsg)
            
            // Move thread to top of list
            if let index = threads.firstIndex(where: { $0.id == thread.id }) {
                let movedThread = threads.remove(at: index)
                threads.insert(movedThread, at: 0)
            }
            
        } catch let ragError as RAGError {
            // Handle RAG-specific errors with a helpful response
            print("ChatViewModel: RAG error: \(ragError)")
            
            let errorResponse = buildErrorResponse(for: ragError)
            let errorMessage = ChatMessage(
                id: UUID(),
                threadId: thread.id,
                role: .assistant,
                content: errorResponse,
                createdAt: Date()
            )
            if let saved = try? await repository.createMessage(errorMessage) {
                self.messages.append(saved)
            }
            
            self.error = ragError
            self.errorMessage = ragError.localizedDescription
            
        } catch {
            self.error = error
            self.errorMessage = error.localizedDescription
            print("Chat error: \(error)")
        }
        
        self.isSending = false
    }
    
    /// Build a helpful error response for different RAG failures
    private func buildErrorResponse(for error: RAGError) -> String {
        switch error {
        case .missingOpenAIKey:
            return """
            ⚠️ **OpenAI API Key Required**
            
            I can't search your recordings because the OpenAI API key isn't configured. This key is needed to generate embeddings for semantic search.
            
            **To fix this:**
            1. Go to **Settings** (gear icon)
            2. Add your OpenAI API key
            3. Try your question again
            """
            
        case .missingAPIKey:
            return """
            ⚠️ **Claude API Key Required**
            
            I can't generate responses because the Claude API key isn't configured.
            
            **To fix this:**
            1. Go to **Settings** (gear icon)
            2. Add your Claude API key
            3. Try your question again
            """
            
        case .searchFailed(let reason):
            return """
            ⚠️ **Search Error**
            
            There was a problem searching your data: \(reason)
            
            This might mean the search function hasn't been set up in your database. Please check the Supabase configuration.
            """
            
        case .databaseNotInitialized:
            return """
            ⚠️ **Database Not Connected**
            
            I can't access your data because the database connection isn't initialized.
            
            **To fix this:**
            1. Go to **Settings**
            2. Verify your Supabase credentials
            3. Restart the app
            """
            
        case .embeddingFailed:
            return """
            ⚠️ **Embedding Generation Failed**
            
            I couldn't process your question for search. This usually means:
            - The OpenAI API key is invalid
            - There's a network issue
            
            Please check your API key in Settings.
            """
            
        default:
            return "⚠️ An error occurred: \(error.localizedDescription)"
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
    
    private func createNewThreadAndSend(_ content: String) async {
        do {
            let newThread = ChatThread(
                id: UUID(),
                title: generateThreadTitle(from: content),
                createdAt: Date(),
                updatedAt: Date()
            )
            let created = try await repository.createThread(newThread)
            self.threads.insert(created, at: 0)
            self.selectedThread = created
            self.messages = []
            
            // Now send the message
            await sendMessage(content)
        } catch {
            self.error = error
        }
    }
    
    /// Generate a short title from the first message
    private func generateThreadTitle(from message: String) -> String {
        // Truncate to first 50 chars or first sentence
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find first sentence end
        if let endIndex = trimmed.firstIndex(where: { $0 == "." || $0 == "?" || $0 == "!" }) {
            let sentence = String(trimmed[...endIndex])
            if sentence.count <= 50 {
                return sentence
            }
        }
        
        // Truncate to 50 chars
        if trimmed.count <= 50 {
            return trimmed
        }
        
        let truncated = String(trimmed.prefix(47))
        // Try to break at word boundary
        if let lastSpace = truncated.lastIndex(of: " ") {
            return String(truncated[..<lastSpace]) + "..."
        }
        return truncated + "..."
    }
    
    func dismissError() {
        errorMessage = nil
    }
}
