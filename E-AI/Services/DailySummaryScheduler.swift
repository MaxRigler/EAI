// DailySummaryScheduler.swift
// Scheduled job for generating nightly daily summaries

import Foundation

/// Scheduler for automatic daily summary generation at 11:59 PM
class DailySummaryScheduler {
    static let shared = DailySummaryScheduler()
    
    private var timer: Timer?
    private var isRunning = false
    
    private init() {}
    
    // MARK: - Public API
    
    /// Start the scheduler - call this on app launch
    func start() {
        guard !isRunning else { return }
        isRunning = true
        
        print("DailySummaryScheduler: Starting...")
        
        // Schedule the next run
        scheduleNextRun()
        
        // Also check if we missed yesterday's summary (app wasn't running at 11:59 PM)
        Task {
            await checkForMissedSummaries()
        }
    }
    
    /// Stop the scheduler
    func stop() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        print("DailySummaryScheduler: Stopped")
    }
    
    /// Manually trigger summary generation for today
    func generateTodaySummary() async throws -> DailySummary {
        return try await DailySummaryService.shared.generateDailySummary(for: Date())
    }
    
    // MARK: - Private Methods
    
    private func scheduleNextRun() {
        timer?.invalidate()
        
        // Calculate time until 11:59 PM today (or tomorrow if already past)
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = 23
        components.minute = 59
        components.second = 0
        
        guard var scheduleDate = calendar.date(from: components) else {
            print("DailySummaryScheduler: Failed to calculate schedule date")
            return
        }
        
        // If it's already past 11:59 PM today, schedule for tomorrow
        if scheduleDate <= Date() {
            scheduleDate = calendar.date(byAdding: .day, value: 1, to: scheduleDate) ?? scheduleDate
        }
        
        let timeInterval = scheduleDate.timeIntervalSinceNow
        
        print("DailySummaryScheduler: Next run scheduled for \(scheduleDate) (in \(Int(timeInterval / 60)) minutes)")
        
        // Schedule the timer on the main run loop
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(
                withTimeInterval: timeInterval,
                repeats: false
            ) { [weak self] _ in
                self?.timerFired()
            }
            
            // Ensure timer fires even when app is in background
            if let timer = self?.timer {
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }
    
    private func timerFired() {
        print("DailySummaryScheduler: ⏰ Timer fired - generating daily summary")
        
        Task {
            do {
                let summary = try await DailySummaryService.shared.generateDailySummary(for: Date())
                print("DailySummaryScheduler: ✅ Daily summary generated successfully (\(summary.recordingCount) recordings)")
            } catch {
                print("DailySummaryScheduler: ❌ Failed to generate daily summary: \(error)")
            }
            
            // Schedule the next run for tomorrow
            scheduleNextRun()
        }
    }
    
    /// Check if we missed generating any summaries (e.g., app wasn't running at 11:59 PM)
    private func checkForMissedSummaries() async {
        let calendar = Calendar.current
        let today = Date()
        
        // Check yesterday - if no summary exists and it's a new day
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else { return }
        
        let dailyRepository = DailyRepository()
        
        do {
            // Check if yesterday has a summary
            if let existingSummary = try await dailyRepository.fetchDailySummary(for: yesterday) {
                print("DailySummaryScheduler: Yesterday's summary exists (\(existingSummary.recordingCount) recordings)")
            } else {
                // No summary for yesterday - check if there were any recordings
                let recordingRepository = RecordingRepository()
                let recordings = try await recordingRepository.fetchRecordings(for: yesterday)
                
                if !recordings.isEmpty {
                    print("DailySummaryScheduler: Found \(recordings.count) recordings from yesterday without summary, generating...")
                    let summary = try await DailySummaryService.shared.generateDailySummary(for: yesterday)
                    print("DailySummaryScheduler: ✅ Generated missed summary for yesterday (\(summary.recordingCount) recordings)")
                } else {
                    print("DailySummaryScheduler: No recordings from yesterday, skipping summary")
                }
            }
        } catch {
            print("DailySummaryScheduler: Error checking for missed summaries: \(error)")
        }
    }
}
