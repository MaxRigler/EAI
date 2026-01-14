// EmailSyncScheduler.swift
// Background scheduler for automatic email synchronization

import Foundation

/// Scheduler for automatic email sync
/// Runs every hour from 6:00 AM to 8:00 PM on weekdays
class EmailSyncScheduler {
    static let shared = EmailSyncScheduler()
    
    private var timer: Timer?
    private var isRunning = false
    
    // Schedule configuration
    private let startHour = 6   // 6:00 AM
    private let endHour = 20    // 8:00 PM
    private let syncIntervalMinutes = 60  // Every hour
    
    private init() {}
    
    // MARK: - Public Properties
    
    var isSchedulerRunning: Bool {
        return isRunning
    }
    
    var nextSyncTime: Date? {
        guard isRunning else { return nil }
        return calculateNextSyncTime()
    }
    
    // MARK: - Public Methods
    
    /// Start the scheduler
    func start() {
        guard !isRunning else {
            print("EmailSyncScheduler: Already running")
            return
        }
        
        isRunning = true
        scheduleNextSync()
        print("EmailSyncScheduler: Started")
    }
    
    /// Stop the scheduler
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        print("EmailSyncScheduler: Stopped")
    }
    
    /// Manually trigger a sync now
    func syncNow() async {
        guard GmailAuthService.shared.isAuthenticated else {
            print("EmailSyncScheduler: Cannot sync - not authenticated")
            return
        }
        
        print("EmailSyncScheduler: Manual sync triggered")
        do {
            let count = try await EmailSyncService.shared.syncAllContactEmails()
            print("EmailSyncScheduler: Manual sync complete - \(count) new emails")
        } catch {
            print("EmailSyncScheduler: Manual sync failed - \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private func scheduleNextSync() {
        guard isRunning else { return }
        
        // Calculate time until next sync
        let nextSync = calculateNextSyncTime()
        let interval = nextSync.timeIntervalSinceNow
        
        guard interval > 0 else {
            // Should sync now, then reschedule
            performSync()
            return
        }
        
        print("EmailSyncScheduler: Next sync at \(nextSync.formatted(date: .omitted, time: .shortened))")
        
        // Schedule timer
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
                self?.performSync()
            }
        }
    }
    
    private func performSync() {
        guard isRunning else { return }
        guard shouldSyncNow() else {
            // Outside sync window, schedule for next valid time
            scheduleNextSync()
            return
        }
        
        Task {
            print("EmailSyncScheduler: Scheduled sync started")
            do {
                let count = try await EmailSyncService.shared.syncAllContactEmails()
                print("EmailSyncScheduler: Scheduled sync complete - \(count) new emails")
            } catch {
                print("EmailSyncScheduler: Scheduled sync failed - \(error)")
            }
            
            // Schedule next sync
            await MainActor.run {
                self.scheduleNextSync()
            }
        }
    }
    
    private func shouldSyncNow() -> Bool {
        let calendar = Calendar.current
        let now = Date()
        
        // Check if it's a weekday (Monday = 2, Friday = 6)
        let weekday = calendar.component(.weekday, from: now)
        guard weekday >= 2 && weekday <= 6 else {
            return false
        }
        
        // Check if within time window
        let hour = calendar.component(.hour, from: now)
        return hour >= startHour && hour < endHour
    }
    
    private func calculateNextSyncTime() -> Date {
        let calendar = Calendar.current
        var now = Date()
        
        // Find the next valid sync time
        for _ in 0..<7 {
            let weekday = calendar.component(.weekday, from: now)
            let hour = calendar.component(.hour, from: now)
            let minute = calendar.component(.minute, from: now)
            
            // If it's a weekday
            if weekday >= 2 && weekday <= 6 {
                // If we're before the start time, schedule for start time today
                if hour < startHour {
                    return calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)!
                }
                
                // If we're within the window, schedule for next hour
                if hour < endHour {
                    // Round up to next hour
                    let nextHour = hour + 1
                    if nextHour < endHour {
                        return calendar.date(bySettingHour: nextHour, minute: 0, second: 0, of: now)!
                    }
                }
            }
            
            // Move to next day at start time
            now = calendar.date(byAdding: .day, value: 1, to: now)!
            now = calendar.date(bySettingHour: startHour, minute: 0, second: 0, of: now)!
        }
        
        // Fallback: 1 hour from now (shouldn't reach here)
        return Date().addingTimeInterval(3600)
    }
}
