//
//  ScheduledBackupManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/6/24.
//

import Foundation
import Combine
import AppKit

class ScheduledBackupManager : ObservableObject{
    
    private var backupTimer: DispatchSourceTimer?
    private let backupsService: BackupsService
    private let userDefaults = UserDefaults.standard
    private let queue = DispatchQueue(label: "com.internxt.backup.scheduler")
    private let BACKUP_FREQUENCY_KEY = "INTERNXT_SELECTED_BACKUP_FREQUENCY"
    private let LAST_BACKUP_TIME_KEY = "INTERNXT_LAST_BACKUP_TIME_KEY"
    private let NEXT_SCHEDULED_BACKUP_KEY = "INTERNXT_NEXT_SCHEDULED_BACKUP_KEY"
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    
    @Published var backupError: String = ""
    @Published var nextBackupTime: String = ""
    
    init(backupsService: BackupsService) {
        self.backupsService = backupsService
        setupSleepWakeNotifications()
    }
    
    deinit {
        removeSleepWakeNotifications()
    }
    
    
    private func setupSleepWakeNotifications() {
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemSleep()
        }
        
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.handleSystemWake()
        }
    }
    
    private func removeSleepWakeNotifications() {
        if let sleepObserver = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver)
        }
        if let wakeObserver = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }
    
    private func handleSystemSleep() {
        stopAllTimers()
    }
    
    private func handleSystemWake() {
        resumeBackupScheduler()
    }
    
    func resumeBackupScheduler() {
        guard let rawValue = userDefaults.string(forKey: BACKUP_FREQUENCY_KEY),
              let frequency = BackupFrequencyEnum(rawValue: rawValue),
              frequency != .manually else {
            return
        }
        
        startBackupTimer(frequency: frequency)
    }
    
    func startBackupTimer(frequency: BackupFrequencyEnum) {
        stopAllTimers()
        
        userDefaults.set(frequency.rawValue, forKey: BACKUP_FREQUENCY_KEY)
        
        guard frequency != .manually else {
            userDefaults.removeObject(forKey: LAST_BACKUP_TIME_KEY)
            userDefaults.removeObject(forKey: NEXT_SCHEDULED_BACKUP_KEY)
            DispatchQueue.main.async {
                self.nextBackupTime = ""
            }
            return
        }
        
        let interval = frequency.timeInterval
        let now = Date()
        
        if let savedNextBackup = userDefaults.object(forKey: NEXT_SCHEDULED_BACKUP_KEY) as? Date {
            let timeUntilNext = savedNextBackup.timeIntervalSince(now)
            
            if timeUntilNext <= 0 {
                performBackup()
            } else {
                displayNextBackupTime(savedNextBackup)
                scheduleNextBackup(after: timeUntilNext, interval: interval)
            }
        } else if let lastBackupTime = userDefaults.object(forKey: LAST_BACKUP_TIME_KEY) as? Date {
            let nextScheduledBackup = lastBackupTime.addingTimeInterval(interval)
            let timeUntilNext = nextScheduledBackup.timeIntervalSince(now)
            
            if timeUntilNext <= 0 {
                performBackup()
            } else {
                saveNextScheduledBackup(nextScheduledBackup)
                displayNextBackupTime(nextScheduledBackup)
                scheduleNextBackup(after: timeUntilNext, interval: interval)
            }
        } else {
            let nextBackupDate = now.addingTimeInterval(interval)
            saveNextScheduledBackup(nextBackupDate)
            displayNextBackupTime(nextBackupDate)
            scheduleNextBackup(after: interval, interval: interval)
        }
    }
    
    func cancelScheduledBackups() {
        stopAllTimers()
        DispatchQueue.main.async {
            self.nextBackupTime = ""
        }
    }
    
    
    private func stopAllTimers() {
        queue.async { [weak self] in
            self?.backupTimer?.cancel()
            self?.backupTimer = nil
        }
    }
    
    private func scheduleNextBackup(after delay: TimeInterval, interval: TimeInterval) {
        queue.async { [weak self] in
            guard let self = self else { return }
            
            self.backupTimer?.cancel()
            self.backupTimer = nil
            
            let timer = DispatchSource.makeTimerSource(queue: self.queue)
            timer.schedule(deadline: .now() + delay)
            
            timer.setEventHandler { [weak self] in
                self?.performBackup()
            }
            
            timer.resume()
            self.backupTimer = timer
        }
    }
    
    private func saveNextScheduledBackup(_ date: Date) {
        userDefaults.set(date, forKey: NEXT_SCHEDULED_BACKUP_KEY)
    }
    
    private func clearNextScheduledBackup() {
        userDefaults.removeObject(forKey: NEXT_SCHEDULED_BACKUP_KEY)
    }
    
    private func displayNextBackupTime(_ date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let formattedTime = dateFormatter.string(from: date)
        
        DispatchQueue.main.async {
            self.nextBackupTime = formattedTime
        }
    }
    
    private func performBackup() {
        
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            
            if await MainActor.run(body: { self.backupsService.backupUploadStatus }) == .InProgress {
                await self.scheduleNextBackupAfterCompletion()
                return
            }
            
            do {
                await self.backupsService.loadAllDevices()
                self.backupsService.loadFoldersToBackup()
                try await self.backupsService.startBackup { progress in }
                
                let completionTime = Date()
                self.userDefaults.set(completionTime, forKey: self.LAST_BACKUP_TIME_KEY)
                self.clearNextScheduledBackup()
                
                await MainActor.run {
                    self.backupError = ""
                }
                
                await self.scheduleNextBackupAfterCompletion()
                
            } catch {
                await MainActor.run {
                    self.backupError = error.localizedDescription
                }
                
                await self.scheduleNextBackupAfterCompletion()
            }
        }
    }
    
    private func scheduleNextBackupAfterCompletion() async {
        guard let lastBackupTime = userDefaults.object(forKey: LAST_BACKUP_TIME_KEY) as? Date,
              let rawValue = userDefaults.string(forKey: BACKUP_FREQUENCY_KEY),
              let frequency = BackupFrequencyEnum(rawValue: rawValue),
              frequency != .manually else {
            return
        }
        
        let interval = frequency.timeInterval
        let now = Date()
        
        var nextBackupDate = lastBackupTime.addingTimeInterval(interval)
        
        while nextBackupDate <= now {
            nextBackupDate = nextBackupDate.addingTimeInterval(interval)
        }
        
        let timeUntilNext = nextBackupDate.timeIntervalSince(now)
        let capturedNextBackupDate = nextBackupDate
        
        saveNextScheduledBackup(capturedNextBackupDate)
        
        await MainActor.run {
            self.displayNextBackupTime(capturedNextBackupDate)
            self.scheduleNextBackup(after: timeUntilNext, interval: interval)
        }
    }
}
