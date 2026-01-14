// IMessageSyncService.swift
// Service for reading iMessages from local chat.db database

import Foundation
import SQLite3

/// Service for accessing the local iMessage database
/// Requires Full Disk Access permission to read ~/Library/Messages/chat.db
class IMessageSyncService {
    static let shared = IMessageSyncService()
    
    private let chatDBPath: String
    
    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        self.chatDBPath = "\(home)/Library/Messages/chat.db"
    }
    
    // MARK: - Permission Check
    
    /// Check if app has Full Disk Access to read chat.db
    func checkAccess() -> Bool {
        return FileManager.default.isReadableFile(atPath: chatDBPath)
    }
    
    // MARK: - Fetch Messages
    
    /// Fetch all messages for a given phone number or email address
    /// - Parameter handle: Phone number or email address to search for
    /// - Returns: Array of iMessage records sorted by timestamp
    func fetchMessages(for handle: String) throws -> [IMessageRecord] {
        guard checkAccess() else {
            throw IMessageError.noAccess
        }
        
        var db: OpaquePointer?
        
        // Open database in read-only mode
        let flags = SQLITE_OPEN_READONLY
        guard sqlite3_open_v2(chatDBPath, &db, flags, nil) == SQLITE_OK else {
            throw IMessageError.databaseOpenFailed
        }
        
        defer {
            sqlite3_close(db)
        }
        
        // Normalize the handle for matching
        let normalizedHandle = normalizePhoneNumber(handle)
        
        // Query for messages matching the handle
        // We use LIKE with % to match partial phone numbers
        let query = """
            SELECT 
                m.guid,
                m.text,
                m.date,
                m.is_from_me,
                h.id as handle_id
            FROM message m
            JOIN chat_message_join cmj ON m.ROWID = cmj.message_id
            JOIN chat_handle_join chj ON cmj.chat_id = chj.chat_id
            JOIN handle h ON chj.handle_id = h.ROWID
            WHERE h.id LIKE ?
               OR h.id LIKE ?
            ORDER BY m.date ASC
        """
        
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMessage = String(cString: sqlite3_errmsg(db))
            throw IMessageError.queryFailed(errorMessage)
        }
        
        defer {
            sqlite3_finalize(statement)
        }
        
        // Bind parameters - search for both original and normalized
        let searchPattern1 = "%\(handle)%"
        let searchPattern2 = "%\(normalizedHandle)%"
        
        sqlite3_bind_text(statement, 1, searchPattern1, -1, nil)
        sqlite3_bind_text(statement, 2, searchPattern2, -1, nil)
        
        var messages: [IMessageRecord] = []
        
        while sqlite3_step(statement) == SQLITE_ROW {
            // Extract data from row
            guard let guidPtr = sqlite3_column_text(statement, 0) else { continue }
            let guid = String(cString: guidPtr)
            
            // Text can be null for attachments/reactions
            let text: String
            if let textPtr = sqlite3_column_text(statement, 1) {
                text = String(cString: textPtr)
            } else {
                continue // Skip messages without text
            }
            
            // Skip empty messages
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continue
            }
            
            // Date is stored as Apple Cocoa timestamp (nanoseconds since 2001-01-01)
            let cocoaTimestamp = sqlite3_column_int64(statement, 2)
            let timestamp = convertAppleTimestamp(cocoaTimestamp)
            
            let isFromMe = sqlite3_column_int(statement, 3) == 1
            
            let record = IMessageRecord(
                guid: guid,
                text: text,
                timestamp: timestamp,
                isFromMe: isFromMe
            )
            
            messages.append(record)
        }
        
        return messages
    }
    
    /// Fetch messages for multiple handles (phone + email)
    func fetchMessages(forPhone phone: String?, email: String?) throws -> [IMessageRecord] {
        var allMessages: [IMessageRecord] = []
        var seenGuids = Set<String>()
        
        if let phone = phone, !phone.isEmpty {
            let phoneMessages = try fetchMessages(for: phone)
            for message in phoneMessages {
                if !seenGuids.contains(message.guid) {
                    seenGuids.insert(message.guid)
                    allMessages.append(message)
                }
            }
        }
        
        if let email = email, !email.isEmpty {
            let emailMessages = try fetchMessages(for: email)
            for message in emailMessages {
                if !seenGuids.contains(message.guid) {
                    seenGuids.insert(message.guid)
                    allMessages.append(message)
                }
            }
        }
        
        // Sort by timestamp
        return allMessages.sorted { $0.timestamp < $1.timestamp }
    }
    
    // MARK: - Phone Number Normalization
    
    /// Normalize phone number by extracting last 10 digits
    /// This handles various formats like +1 555-123-4567, (555) 123-4567, etc.
    func normalizePhoneNumber(_ phone: String) -> String {
        // Extract only digits
        let digitsOnly = phone.filter { $0.isNumber }
        
        // Return last 10 digits (US phone number without country code)
        if digitsOnly.count >= 10 {
            return String(digitsOnly.suffix(10))
        }
        
        return digitsOnly
    }
    
    // MARK: - Private Helpers
    
    /// Convert Apple Cocoa timestamp to Date
    /// iMessage uses nanoseconds since 2001-01-01
    private func convertAppleTimestamp(_ timestamp: Int64) -> Date {
        // Apple Cocoa timestamps are in nanoseconds since 2001-01-01
        // Unix epoch is 1970-01-01
        // Difference is 978307200 seconds
        
        let unixTimestamp = TimeInterval(timestamp) / 1_000_000_000.0 + 978307200
        return Date(timeIntervalSince1970: unixTimestamp)
    }
}

// MARK: - Errors

enum IMessageError: LocalizedError {
    case noAccess
    case databaseOpenFailed
    case queryFailed(String)
    case noContactInfo
    
    var errorDescription: String? {
        switch self {
        case .noAccess:
            return "E-AI needs Full Disk Access to read your iMessage history. Please enable it in System Settings → Privacy & Security → Full Disk Access."
        case .databaseOpenFailed:
            return "Failed to open iMessage database. It may be locked by another process."
        case .queryFailed(let message):
            return "Failed to query iMessage database: \(message)"
        case .noContactInfo:
            return "This contact has no phone number or email address to search for."
        }
    }
}
