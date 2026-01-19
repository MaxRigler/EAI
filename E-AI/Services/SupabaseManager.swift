// SupabaseManager.swift
// Supabase client initialization and configuration

import Foundation
import Supabase

@MainActor
class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    @Published private(set) var client: SupabaseClient?
    @Published private(set) var isInitialized = false
    @Published private(set) var error: Error?
    
    private init() {}
    
    // MARK: - Initialization
    
    func initialize() async {
        guard let url = KeychainManager.shared.supabaseURL,
              let key = KeychainManager.shared.supabaseKey,
              let supabaseURL = URL(string: url) else {
            error = SupabaseError.missingCredentials
            return
        }
        
        client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: key
        )
        
        isInitialized = true
        print("SupabaseManager initialized successfully")
    }
    
    // MARK: - Query Helper
    
    /// Safely get the client, returns nil if not initialized
    func getClient() -> SupabaseClient? {
        return client
    }
    
    /// Wait for initialization to complete (with timeout)
    /// Returns true if initialized successfully, false if timeout reached
    func waitForInitialization(timeoutSeconds: Double = 5.0) async -> Bool {
        let deadline = Date().addingTimeInterval(timeoutSeconds)
        while !isInitialized && Date() < deadline {
            try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s polling
        }
        return isInitialized
    }
}

// MARK: - Supabase Error

enum SupabaseError: LocalizedError {
    case missingCredentials
    case notInitialized
    case queryFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingCredentials:
            return "Supabase credentials not configured"
        case .notInitialized:
            return "Supabase client not initialized"
        case .queryFailed(let message):
            return "Database query failed: \(message)"
        }
    }
}

// MARK: - Repository Error

enum RepositoryError: LocalizedError {
    case notInitialized
    case createFailed
    case updateFailed
    case deleteFailed
    case notFound
    
    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Database not initialized"
        case .createFailed:
            return "Failed to create record"
        case .updateFailed:
            return "Failed to update record"
        case .deleteFailed:
            return "Failed to delete record"
        case .notFound:
            return "Record not found"
        }
    }
}
