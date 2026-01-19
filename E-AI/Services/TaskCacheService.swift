// TaskCacheService.swift
// Local caching for tasks to ensure availability even when offline

import Foundation

/// Service for caching tasks locally to provide offline resilience
/// Tasks are cached to a JSON file after successful remote fetch
/// If remote fetch fails, cached tasks are returned with offline indicator
actor TaskCacheService {
    static let shared = TaskCacheService()
    
    private let cacheFileName = "tasks_cache.json"
    private let metadataFileName = "tasks_cache_metadata.json"
    
    private init() {}
    
    // MARK: - Cache Metadata
    
    struct CacheMetadata: Codable {
        let lastSyncedAt: Date
        let taskCount: Int
        
        var formattedLastSync: String {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: lastSyncedAt, relativeTo: Date())
        }
    }
    
    // MARK: - Cache File Paths
    
    private var cacheDirectoryURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("E-AI", isDirectory: true)
            .appendingPathComponent("Cache", isDirectory: true)
    }
    
    private var cacheFileURL: URL? {
        cacheDirectoryURL?.appendingPathComponent(cacheFileName)
    }
    
    private var metadataFileURL: URL? {
        cacheDirectoryURL?.appendingPathComponent(metadataFileName)
    }
    
    // MARK: - Public API
    
    /// Save tasks to local cache after successful remote fetch
    func cacheTasks(_ tasks: [AppTask]) async {
        guard let cacheDir = cacheDirectoryURL,
              let cacheURL = cacheFileURL,
              let metadataURL = metadataFileURL else {
            print("⚠️ TaskCacheService: Could not determine cache directory")
            return
        }
        
        do {
            // Ensure cache directory exists
            try FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            // Encode and save tasks
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let tasksData = try encoder.encode(tasks)
            try tasksData.write(to: cacheURL)
            
            // Save metadata
            let metadata = CacheMetadata(lastSyncedAt: Date(), taskCount: tasks.count)
            let metadataData = try encoder.encode(metadata)
            try metadataData.write(to: metadataURL)
            
            print("✅ TaskCacheService: Cached \(tasks.count) tasks to local storage")
        } catch {
            print("⚠️ TaskCacheService: Failed to cache tasks: \(error)")
        }
    }
    
    /// Load tasks from local cache (used when remote fetch fails)
    func loadCachedTasks() async -> (tasks: [AppTask], metadata: CacheMetadata?)? {
        guard let cacheURL = cacheFileURL,
              let metadataURL = metadataFileURL else {
            return nil
        }
        
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            print("⚠️ TaskCacheService: No cached tasks found")
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            // Load tasks
            let tasksData = try Data(contentsOf: cacheURL)
            let tasks = try decoder.decode([AppTask].self, from: tasksData)
            
            // Load metadata
            var metadata: CacheMetadata?
            if FileManager.default.fileExists(atPath: metadataURL.path) {
                let metadataData = try Data(contentsOf: metadataURL)
                metadata = try decoder.decode(CacheMetadata.self, from: metadataData)
            }
            
            print("✅ TaskCacheService: Loaded \(tasks.count) tasks from cache")
            return (tasks, metadata)
        } catch {
            print("⚠️ TaskCacheService: Failed to load cached tasks: \(error)")
            return nil
        }
    }
    
    /// Get cache metadata without loading all tasks
    func getCacheMetadata() async -> CacheMetadata? {
        guard let metadataURL = metadataFileURL,
              FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let metadataData = try Data(contentsOf: metadataURL)
            return try decoder.decode(CacheMetadata.self, from: metadataData)
        } catch {
            return nil
        }
    }
    
    /// Clear the cache (for debugging or forced refresh)
    func clearCache() async {
        guard let cacheURL = cacheFileURL,
              let metadataURL = metadataFileURL else {
            return
        }
        
        try? FileManager.default.removeItem(at: cacheURL)
        try? FileManager.default.removeItem(at: metadataURL)
        print("🗑️ TaskCacheService: Cache cleared")
    }
}
