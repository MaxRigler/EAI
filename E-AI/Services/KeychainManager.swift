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
}
