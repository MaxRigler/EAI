// GmailAPIService.swift
// REST API wrapper for Gmail operations

import Foundation

/// Service for interacting with Gmail REST API
class GmailAPIService {
    static let shared = GmailAPIService()
    
    private let baseURL = "https://gmail.googleapis.com/gmail/v1"
    private let authService = GmailAuthService.shared
    
    private init() {}
    
    // MARK: - Send Email
    
    /// Send an email through Gmail
    func sendEmail(
        to: String,
        subject: String,
        body: String,
        from: String? = nil,
        fromName: String? = nil,
        replyToMessageId: String? = nil,
        threadId: String? = nil
    ) async throws -> GmailMessage {
        let accessToken = try await authService.getValidAccessToken()
        
        // Build MIME message
        let mimeMessage = buildMIMEMessage(
            to: to,
            subject: subject,
            body: body,
            from: from,
            fromName: fromName,
            replyToMessageId: replyToMessageId
        )
        
        // Base64 URL-safe encode
        let encodedMessage = mimeMessage
            .data(using: .utf8)!
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        
        // Build request
        var urlComponents = URLComponents(string: "\(baseURL)/users/me/messages/send")!
        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var payload: [String: Any] = ["raw": encodedMessage]
        if let threadId = threadId {
            payload["threadId"] = threadId
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAPIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("GmailAPIService: Send failed: \(errorBody)")
            throw GmailAPIError.sendFailed("Status \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GmailMessage.self, from: data)
    }
    
    // MARK: - Fetch Emails
    
    /// Fetch emails for a specific email address (to or from)
    func fetchEmails(
        forEmailAddress email: String,
        after: Date? = nil,
        maxResults: Int = 50
    ) async throws -> [GmailMessage] {
        let accessToken = try await authService.getValidAccessToken()
        
        // Build query
        var queryParts = ["(to:\(email) OR from:\(email))"]
        if let after = after {
            let timestamp = Int(after.timeIntervalSince1970)
            queryParts.append("after:\(timestamp)")
        }
        let query = queryParts.joined(separator: " ")
        
        // List messages
        var urlComponents = URLComponents(string: "\(baseURL)/users/me/messages")!
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "maxResults", value: String(maxResults))
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailAPIError.fetchFailed("Failed to list messages")
        }
        
        let listResponse = try JSONDecoder().decode(GmailMessageListResponse.self, from: data)
        
        // Fetch full message details for each
        var messages: [GmailMessage] = []
        for messageRef in listResponse.messages ?? [] {
            do {
                let fullMessage = try await getMessage(id: messageRef.id)
                messages.append(fullMessage)
            } catch {
                print("GmailAPIService: Failed to fetch message \(messageRef.id): \(error)")
            }
        }
        
        return messages
    }
    
    /// Get full message details by ID
    func getMessage(id: String) async throws -> GmailMessage {
        let accessToken = try await authService.getValidAccessToken()
        
        var urlComponents = URLComponents(string: "\(baseURL)/users/me/messages/\(id)")!
        urlComponents.queryItems = [
            URLQueryItem(name: "format", value: "full")
        ]
        
        var request = URLRequest(url: urlComponents.url!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailAPIError.fetchFailed("Failed to get message \(id)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(GmailMessage.self, from: data)
    }
    
    /// Get the authenticated user's email address
    func getUserEmail() async throws -> String {
        let accessToken = try await authService.getValidAccessToken()
        
        var request = URLRequest(url: URL(string: "\(baseURL)/users/me/profile")!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GmailAPIError.fetchFailed("Failed to get user profile")
        }
        
        let profile = try JSONDecoder().decode(GmailProfile.self, from: data)
        return profile.emailAddress
    }
    
    // MARK: - Private Helpers
    
    private func buildMIMEMessage(
        to: String,
        subject: String,
        body: String,
        from: String?,
        fromName: String?,
        replyToMessageId: String?
    ) -> String {
        var headers = [
            "To: \(to)",
            "Subject: \(subject)",
            "MIME-Version: 1.0",
            "Content-Type: text/html; charset=utf-8"
        ]
        
        // Format From header with display name if available
        if let from = from {
            if let name = fromName, !name.isEmpty {
                // Format: "Display Name" <email@example.com>
                let fromHeader = "From: \"\(name)\" <\(from)>"
                print("GmailAPIService: Setting From header: \(fromHeader)")
                headers.insert(fromHeader, at: 0)
            } else {
                print("GmailAPIService: No display name set, using email only: \(from)")
                headers.insert("From: \(from)", at: 0)
            }
        } else {
            print("GmailAPIService: No 'from' email provided, Gmail will use default")
        }
        
        if let messageId = replyToMessageId {
            headers.append("In-Reply-To: \(messageId)")
            headers.append("References: \(messageId)")
        }
        
        // Convert to simple HTML to avoid SMTP line wrapping issues
        let htmlBody = convertToSimpleHTML(body)
        
        let mimeMessage = headers.joined(separator: "\r\n") + "\r\n\r\n" + htmlBody
        print("GmailAPIService: MIME Headers:\n\(headers.joined(separator: "\n"))")
        
        return mimeMessage
    }
    
    /// Converts plain text to simple HTML - minimal styling to match email client defaults
    private func convertToSimpleHTML(_ text: String) -> String {
        // Escape HTML special characters
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        // Split into paragraphs (double newline = new paragraph)
        let paragraphs = escaped.components(separatedBy: "\n\n")
        
        // Wrap each paragraph in <div> with margin for spacing
        let htmlParagraphs = paragraphs
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { "<div style=\"margin-bottom:1em;\">\($0)</div>" }
            .joined(separator: "\n")
        
        // Minimal HTML - no font specification (uses email client default)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        </head>
        <body>
        \(htmlParagraphs)
        </body>
        </html>
        """
    }
    
    /// Converts plain text to responsive HTML email
    private func convertToResponsiveHTML(_ text: String) -> String {
        // Escape HTML special characters
        let escapedText = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        
        // Convert line breaks to <br> tags and wrap paragraphs
        let paragraphs = escapedText
            .components(separatedBy: "\n\n")
            .map { paragraph in
                let lines = paragraph.components(separatedBy: "\n").joined(separator: "<br>")
                return "<p style=\"margin: 0 0 16px 0;\">\(lines)</p>"
            }
            .joined(separator: "\n")
        
        // Build responsive HTML email - no custom font to use email client's default
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {
                    margin: 0;
                    padding: 0;
                }
                p {
                    margin: 0 0 16px 0;
                }
                a {
                    color: #4A90D9;
                    text-decoration: none;
                }
            </style>
        </head>
        <body>
            \(paragraphs)
        </body>
        </html>
        """
    }
}

// MARK: - API Response Types

struct GmailMessageListResponse: Codable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

struct GmailMessageRef: Codable {
    let id: String
    let threadId: String
}

struct GmailMessage: Codable {
    let id: String
    let threadId: String
    let labelIds: [String]?
    let snippet: String?
    let payload: GmailPayload?
    let internalDate: String?
    
    var subject: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "subject" })?.value
    }
    
    var from: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "from" })?.value
    }
    
    var to: String? {
        payload?.headers?.first(where: { $0.name.lowercased() == "to" })?.value
    }
    
    var date: Date? {
        guard let internalDate = internalDate,
              let timestamp = Double(internalDate) else { return nil }
        return Date(timeIntervalSince1970: timestamp / 1000)
    }
    
    var body: String? {
        extractBody(from: payload)
    }
    
    /// Extract sender email from "From" header
    var senderEmail: String? {
        guard let from = from else { return nil }
        // Parse "Name <email@example.com>" or just "email@example.com"
        if let match = from.range(of: "<([^>]+)>", options: .regularExpression) {
            let email = from[match].dropFirst().dropLast()
            return String(email)
        }
        return from.trimmingCharacters(in: .whitespaces)
    }
    
    /// Extract sender name from "From" header
    var senderName: String? {
        guard let from = from else { return nil }
        if let match = from.range(of: "^[^<]+", options: .regularExpression) {
            let name = from[match].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty && !name.contains("@") {
                return name
            }
        }
        return nil
    }
    
    private func extractBody(from payload: GmailPayload?) -> String? {
        guard let payload = payload else { return nil }
        
        // Check for body data directly
        if let bodyData = payload.body?.data {
            return decodeBase64URL(bodyData)
        }
        
        // Check parts for text/plain
        if let parts = payload.parts {
            for part in parts {
                if part.mimeType == "text/plain", let data = part.body?.data {
                    return decodeBase64URL(data)
                }
            }
            // Fallback to text/html if no plain text
            for part in parts {
                if part.mimeType == "text/html", let data = part.body?.data {
                    return stripHTML(decodeBase64URL(data) ?? "")
                }
            }
            // Check nested parts
            for part in parts {
                if let nestedBody = extractBody(from: part) {
                    return nestedBody
                }
            }
        }
        
        return nil
    }
    
    private func decodeBase64URL(_ base64URL: String) -> String? {
        var base64 = base64URL
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        
        // Add padding if needed
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    private func stripHTML(_ html: String) -> String {
        // Simple HTML stripping
        return html
            .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct GmailPayload: Codable {
    let mimeType: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?
}

struct GmailHeader: Codable {
    let name: String
    let value: String
}

struct GmailBody: Codable {
    let size: Int?
    let data: String?
}

struct GmailProfile: Codable {
    let emailAddress: String
    let messagesTotal: Int?
    let threadsTotal: Int?
    let historyId: String?
}

// MARK: - Errors

enum GmailAPIError: LocalizedError {
    case invalidResponse
    case sendFailed(String)
    case fetchFailed(String)
    case notAuthenticated
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Gmail API"
        case .sendFailed(let message):
            return "Failed to send email: \(message)"
        case .fetchFailed(let message):
            return "Failed to fetch emails: \(message)"
        case .notAuthenticated:
            return "Not authenticated with Gmail"
        }
    }
}
