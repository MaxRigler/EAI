// IMessageChunkManager.swift
// Service for grouping messages into daily chunks and syncing to Supabase

import Foundation

/// Manages the sync process: groups messages by date, formats content, and syncs to Supabase
class IMessageChunkManager {
    static let shared = IMessageChunkManager()
    
    private let syncService = IMessageSyncService.shared
    private let repository = IMessageRepository()
    private let embeddingService = EmbeddingService.shared
    
    // User name for formatting outbound messages
    private let userName = "Max"  // TODO: Could fetch from Apple Contacts or app settings
    
    private init() {}
    
    // MARK: - Public API
    
    /// Sync iMessages for a contact and return count of new messages synced
    /// - Parameter contact: The CRM contact to sync messages for
    /// - Returns: Number of new messages synced
    func syncMessages(for contact: CRMContact) async throws -> Int {
        // Verify we have contact info to search
        guard contact.phone != nil || contact.email != nil else {
            throw IMessageError.noContactInfo
        }
        
        // Check access first
        guard syncService.checkAccess() else {
            throw IMessageError.noAccess
        }
        
        // Fetch all messages from local database
        let messages = try syncService.fetchMessages(
            forPhone: contact.phone,
            email: contact.email
        )
        
        if messages.isEmpty {
            return 0
        }
        
        // Group messages by date
        let groupedByDate = groupByDate(messages)
        
        // Get first name for message formatting
        let contactFirstName = contact.name.components(separatedBy: " ").first ?? contact.name
        
        var newMessageCount = 0
        
        // Process each day
        for (date, dayMessages) in groupedByDate {
            // Fetch existing GUIDs for this date to check for duplicates
            let existingGuids = try await repository.fetchExistingGuids(
                contactId: contact.id,
                date: date
            )
            
            // Filter to only new messages
            let existingGuidSet = Set(existingGuids)
            let newMessages = dayMessages.filter { !existingGuidSet.contains($0.guid) }
            
            if newMessages.isEmpty {
                continue
            }
            
            newMessageCount += newMessages.count
            
            // Combine existing and new messages for the chunk
            let allDayMessages = dayMessages
            
            // Format content for RAG
            let content = formatDailyContent(
                messages: allDayMessages,
                contactName: contactFirstName,
                userName: userName
            )
            
            // Build raw messages array
            let rawMessages = allDayMessages.map { msg in
                IMessageChunk.RawMessage(
                    guid: msg.guid,
                    text: msg.text,
                    direction: msg.direction,
                    timestamp: msg.timestamp
                )
            }
            
            // Build all GUIDs (existing + new)
            let allGuids = allDayMessages.map { $0.guid }
            
            // Check if chunk exists for this date
            if let existingChunk = try await repository.fetchChunk(
                contactId: contact.id,
                date: date
            ) {
                // Update existing chunk
                var updatedChunk = existingChunk
                updatedChunk.content = content
                updatedChunk.messageCount = allDayMessages.count
                updatedChunk.messageGuids = allGuids
                updatedChunk.rawMessages = rawMessages
                updatedChunk.updatedAt = Date()
                
                let savedChunk = try await repository.updateChunk(updatedChunk)
                
                // Generate and save embedding
                try await generateAndSaveEmbedding(for: savedChunk)
            } else {
                // Create new chunk
                let newChunk = IMessageChunk(
                    contactId: contact.id,
                    date: date,
                    content: content,
                    messageCount: allDayMessages.count,
                    messageGuids: allGuids,
                    rawMessages: rawMessages,
                    createdAt: Date()
                )
                
                let savedChunk = try await repository.createChunk(newChunk)
                
                // Generate and save embedding
                try await generateAndSaveEmbedding(for: savedChunk)
            }
        }
        
        return newMessageCount
    }
    
    // MARK: - Message Grouping
    
    /// Group messages by date (calendar day)
    func groupByDate(_ messages: [IMessageRecord]) -> [Date: [IMessageRecord]] {
        let calendar = Calendar.current
        
        var grouped: [Date: [IMessageRecord]] = [:]
        
        for message in messages {
            // Get start of day for grouping
            let dayStart = calendar.startOfDay(for: message.timestamp)
            
            if grouped[dayStart] == nil {
                grouped[dayStart] = []
            }
            grouped[dayStart]?.append(message)
        }
        
        return grouped
    }
    
    // MARK: - Content Formatting
    
    /// Format a day's messages into readable content for RAG
    func formatDailyContent(
        messages: [IMessageRecord],
        contactName: String,
        userName: String
    ) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        
        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .none
        timeFormatter.timeStyle = .short
        
        guard let firstMessage = messages.first else {
            return ""
        }
        
        let dateHeader = dateFormatter.string(from: firstMessage.timestamp)
        
        var lines: [String] = [
            "iMessage conversation – \(dateHeader)",
            ""
        ]
        
        for message in messages {
            let sender = message.isFromMe ? userName : contactName
            let timestamp = timeFormatter.string(from: message.timestamp)
            lines.append("[\(timestamp)] \(sender): \(message.text)")
        }
        
        return lines.joined(separator: "\n")
    }
    
    // MARK: - Embedding
    
    private func generateAndSaveEmbedding(for chunk: IMessageChunk) async throws {
        // Generate embedding for the content
        let embedding = try await embeddingService.generateEmbedding(for: chunk.content)
        
        // Save to database
        try await repository.updateChunkEmbedding(chunkId: chunk.id, embedding: embedding)
        
        print("IMessageChunkManager: Generated embedding for chunk \(chunk.id)")
    }
}
