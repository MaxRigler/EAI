// KeychainManager.swift
// Simplified storage using UserDefaults (development mode)
// TODO: Switch to Keychain for production builds

import Foundation

class KeychainManager {
    static let shared = KeychainManager()
    
    private let defaults = UserDefaults.standard
    
    private enum Key: String {
        case supabaseURL = "eai_supabase_url"
        case supabaseKey = "eai_supabase_key"
        case claudeAPIKey = "eai_claude_api_key"
        case openaiAPIKey = "eai_openai_api_key"
        // Gmail OAuth tokens
        case gmailAccessToken = "eai_gmail_access_token"
        case gmailRefreshToken = "eai_gmail_refresh_token"
        case gmailTokenExpiry = "eai_gmail_token_expiry"
    }
    
    private init() {}
    
    // MARK: - Public Properties
    
    var hasRequiredKeys: Bool {
        return supabaseURL != nil &&
               supabaseKey != nil &&
               claudeAPIKey != nil &&
               openaiAPIKey != nil
    }
    
    var supabaseURL: String? {
        return defaults.string(forKey: Key.supabaseURL.rawValue)
    }
    
    var supabaseKey: String? {
        return defaults.string(forKey: Key.supabaseKey.rawValue)
    }
    
    var claudeAPIKey: String? {
        return defaults.string(forKey: Key.claudeAPIKey.rawValue)
    }
    
    var openaiAPIKey: String? {
        return defaults.string(forKey: Key.openaiAPIKey.rawValue)
    }
    
    // MARK: - Gmail Properties
    
    var gmailAccessToken: String? {
        return defaults.string(forKey: Key.gmailAccessToken.rawValue)
    }
    
    var gmailRefreshToken: String? {
        return defaults.string(forKey: Key.gmailRefreshToken.rawValue)
    }
    
    var gmailTokenExpiry: Date? {
        guard let timestamp = defaults.object(forKey: Key.gmailTokenExpiry.rawValue) as? TimeInterval else {
            return nil
        }
        return Date(timeIntervalSince1970: timestamp)
    }
    
    var isGmailAuthenticated: Bool {
        return gmailRefreshToken != nil
    }
    
    var isGmailTokenValid: Bool {
        guard let accessToken = gmailAccessToken,
              let expiry = gmailTokenExpiry,
              !accessToken.isEmpty else {
            return false
        }
        // Consider token invalid if it expires within 5 minutes
        return expiry > Date().addingTimeInterval(300)
    }
    
    // MARK: - Setters
    
    func setSupabaseURL(_ value: String) throws {
        defaults.set(value, forKey: Key.supabaseURL.rawValue)
    }
    
    func setSupabaseKey(_ value: String) throws {
        defaults.set(value, forKey: Key.supabaseKey.rawValue)
    }
    
    func setClaudeAPIKey(_ value: String) throws {
        defaults.set(value, forKey: Key.claudeAPIKey.rawValue)
    }
    
    func setOpenAIAPIKey(_ value: String) throws {
        defaults.set(value, forKey: Key.openaiAPIKey.rawValue)
    }
    
    // MARK: - Gmail Setters
    
    func setGmailAccessToken(_ value: String) {
        defaults.set(value, forKey: Key.gmailAccessToken.rawValue)
    }
    
    func setGmailRefreshToken(_ value: String) {
        defaults.set(value, forKey: Key.gmailRefreshToken.rawValue)
    }
    
    func setGmailTokenExpiry(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: Key.gmailTokenExpiry.rawValue)
    }
    
    func clearGmailTokens() {
        defaults.removeObject(forKey: Key.gmailAccessToken.rawValue)
        defaults.removeObject(forKey: Key.gmailRefreshToken.rawValue)
        defaults.removeObject(forKey: Key.gmailTokenExpiry.rawValue)
    }
}
