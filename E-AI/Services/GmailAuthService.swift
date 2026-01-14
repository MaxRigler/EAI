// GmailAuthService.swift
// OAuth 2.0 authentication for Gmail API

import Foundation
import AuthenticationServices

/// Handles Gmail OAuth 2.0 authentication flow
class GmailAuthService: NSObject, ObservableObject {
    static let shared = GmailAuthService()
    
    // OAuth Configuration - Set these in environment variables or Xcode scheme
    // GMAIL_CLIENT_ID and GMAIL_CLIENT_SECRET
    private var clientId: String {
        ProcessInfo.processInfo.environment["GMAIL_CLIENT_ID"] ?? ""
    }
    private var clientSecret: String {
        ProcessInfo.processInfo.environment["GMAIL_CLIENT_SECRET"] ?? ""
    }
    private let redirectUri = "http://127.0.0.1:8089/oauth/callback"
    private let scopes = [
        "https://www.googleapis.com/auth/gmail.send",
        "https://www.googleapis.com/auth/gmail.readonly"
    ]
    
    // Google OAuth endpoints
    private let authorizationEndpoint = "https://accounts.google.com/o/oauth2/v2/auth"
    private let tokenEndpoint = "https://oauth2.googleapis.com/token"
    
    // Published state
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false
    @Published var authError: String?
    
    // Local server for OAuth callback
    private var localServer: LocalOAuthServer?
    
    private override init() {
        super.init()
        // Check if we already have tokens
        isAuthenticated = KeychainManager.shared.isGmailAuthenticated
    }
    
    // MARK: - Public Methods
    
    /// Start the OAuth authentication flow
    @MainActor
    func authenticate() async throws -> Bool {
        guard !isAuthenticating else { return false }
        
        isAuthenticating = true
        authError = nil
        
        defer { isAuthenticating = false }
        
        do {
            // Generate PKCE code verifier and challenge
            let codeVerifier = generateCodeVerifier()
            let codeChallenge = generateCodeChallenge(from: codeVerifier)
            
            // Start local server to receive callback
            localServer = LocalOAuthServer(port: 8089)
            try await localServer?.start()
            
            // Build authorization URL
            let authURL = buildAuthorizationURL(codeChallenge: codeChallenge)
            
            // Open in default browser
            NSWorkspace.shared.open(authURL)
            
            // Wait for authorization code from callback
            guard let authCode = try await localServer?.waitForAuthorizationCode(timeout: 120) else {
                throw GmailAuthError.authorizationFailed("No authorization code received")
            }
            
            // Exchange code for tokens
            let tokens = try await exchangeCodeForTokens(code: authCode, codeVerifier: codeVerifier)
            
            // Save tokens
            KeychainManager.shared.setGmailAccessToken(tokens.accessToken)
            KeychainManager.shared.setGmailRefreshToken(tokens.refreshToken)
            KeychainManager.shared.setGmailTokenExpiry(tokens.expiresAt)
            
            isAuthenticated = true
            print("GmailAuthService: Authentication successful")
            return true
            
        } catch {
            authError = error.localizedDescription
            print("GmailAuthService: Authentication failed: \(error)")
            throw error
        }
    }
    
    /// Get a valid access token, refreshing if necessary
    func getValidAccessToken() async throws -> String {
        // Check if current token is valid
        if KeychainManager.shared.isGmailTokenValid,
           let accessToken = KeychainManager.shared.gmailAccessToken {
            return accessToken
        }
        
        // Try to refresh
        guard let refreshToken = KeychainManager.shared.gmailRefreshToken else {
            throw GmailAuthError.notAuthenticated
        }
        
        return try await refreshAccessToken(refreshToken: refreshToken)
    }
    
    /// Sign out and clear tokens
    func signOut() {
        KeychainManager.shared.clearGmailTokens()
        isAuthenticated = false
        print("GmailAuthService: Signed out")
    }
    
    // MARK: - Private Methods
    
    private func buildAuthorizationURL(codeChallenge: String) -> URL {
        var components = URLComponents(string: authorizationEndpoint)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }
    
    private func exchangeCodeForTokens(code: String, codeVerifier: String) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": redirectUri
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailAuthError.networkError("Invalid response")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("GmailAuthService: Token exchange failed: \(errorBody)")
            throw GmailAuthError.tokenExchangeFailed("Status \(httpResponse.statusCode): \(errorBody)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenData = try decoder.decode(GoogleTokenResponse.self, from: data)
        
        return TokenResponse(
            accessToken: tokenData.accessToken,
            refreshToken: tokenData.refreshToken ?? "",
            expiresAt: Date().addingTimeInterval(TimeInterval(tokenData.expiresIn))
        )
    }
    
    private func refreshAccessToken(refreshToken: String) async throws -> String {
        var request = URLRequest(url: URL(string: tokenEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let bodyParams = [
            "client_id": clientId,
            "client_secret": clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]
        
        request.httpBody = bodyParams
            .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            // Refresh token might be revoked
            signOut()
            throw GmailAuthError.tokenRefreshFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let tokenData = try decoder.decode(GoogleTokenResponse.self, from: data)
        
        // Save new access token
        KeychainManager.shared.setGmailAccessToken(tokenData.accessToken)
        KeychainManager.shared.setGmailTokenExpiry(Date().addingTimeInterval(TimeInterval(tokenData.expiresIn)))
        
        print("GmailAuthService: Token refreshed successfully")
        return tokenData.accessToken
    }
    
    // MARK: - PKCE Helpers
    
    private func generateCodeVerifier() -> String {
        var buffer = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, buffer.count, &buffer)
        return Data(buffer).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
    
    private func generateCodeChallenge(from verifier: String) -> String {
        guard let data = verifier.data(using: .utf8) else { return "" }
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

// MARK: - Supporting Types

private struct GoogleTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let scope: String?
    let tokenType: String
}

private struct TokenResponse {
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

enum GmailAuthError: LocalizedError {
    case notAuthenticated
    case authorizationFailed(String)
    case tokenExchangeFailed(String)
    case tokenRefreshFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Gmail. Please sign in."
        case .authorizationFailed(let message):
            return "Authorization failed: \(message)"
        case .tokenExchangeFailed(let message):
            return "Token exchange failed: \(message)"
        case .tokenRefreshFailed:
            return "Failed to refresh Gmail access. Please sign in again."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Local OAuth Server

/// Simple local HTTP server to receive OAuth callback
private class LocalOAuthServer {
    private let port: UInt16
    private var authorizationCode: String?
    private var continuation: CheckedContinuation<String?, Error>?
    private var serverSocket: Int32 = -1
    private var isRunning = false
    
    init(port: UInt16) {
        self.port = port
    }
    
    func start() async throws {
        serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw GmailAuthError.networkError("Failed to create socket")
        }
        
        var value: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &value, socklen_t(MemoryLayout<Int32>.size))
        
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        
        let bindResult = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        
        guard bindResult >= 0 else {
            close(serverSocket)
            throw GmailAuthError.networkError("Failed to bind to port \(port)")
        }
        
        guard listen(serverSocket, 1) >= 0 else {
            close(serverSocket)
            throw GmailAuthError.networkError("Failed to listen on port \(port)")
        }
        
        isRunning = true
        print("LocalOAuthServer: Listening on port \(port)")
    }
    
    func waitForAuthorizationCode(timeout: TimeInterval) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            // Start accepting connections in background
            Task {
                await self.acceptConnection()
            }
            
            // Set timeout
            Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if self.authorizationCode == nil {
                    self.stop()
                    self.continuation?.resume(returning: nil)
                    self.continuation = nil
                }
            }
        }
    }
    
    private func acceptConnection() async {
        guard isRunning else { return }
        
        var clientAddr = sockaddr_in()
        var clientAddrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        
        let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                accept(serverSocket, $0, &clientAddrLen)
            }
        }
        
        guard clientSocket >= 0 else {
            return
        }
        
        // Read request
        var buffer = [UInt8](repeating: 0, count: 4096)
        let bytesRead = read(clientSocket, &buffer, buffer.count)
        
        if bytesRead > 0 {
            let requestString = String(bytes: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
            
            // Extract authorization code from GET request
            if let codeRange = requestString.range(of: "code="),
               let endRange = requestString[codeRange.upperBound...].range(of: "&") ?? requestString[codeRange.upperBound...].range(of: " ") {
                let code = String(requestString[codeRange.upperBound..<endRange.lowerBound])
                authorizationCode = code.removingPercentEncoding ?? code
            }
            
            // Send success response
            let successHTML = """
            HTTP/1.1 200 OK\r
            Content-Type: text/html\r
            \r
            <!DOCTYPE html>
            <html>
            <head><title>E-AI Gmail Authorization</title></head>
            <body style="font-family: -apple-system, sans-serif; text-align: center; padding: 50px;">
                <h1>✅ Authorization Successful</h1>
                <p>You can close this window and return to E-AI.</p>
            </body>
            </html>
            """
            
            _ = successHTML.withCString { ptr in
                write(clientSocket, ptr, strlen(ptr))
            }
        }
        
        close(clientSocket)
        stop()
        
        continuation?.resume(returning: authorizationCode)
        continuation = nil
    }
    
    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }
}

// Import CommonCrypto for SHA256
import CommonCrypto
