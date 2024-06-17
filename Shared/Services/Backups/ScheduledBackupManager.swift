//
//  ScheduledBackupManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/6/24.
//

import Foundation
import Combine

class ScheduledBackupManager : ObservableObject{
    
    private var backupTimer: AnyCancellable?
    private let backupsService: BackupsService
    private let userDefaults = UserDefaults.standard
    private var initialTimer: Timer?
    private let BACKUP_FREQUENCY_KEY = "INTERNXT_SELECTED_BACKUP_FREQUENCY"
    private let LAST_BACKUP_TIME_KEY = "INTERNXT_LAST_BACKUP_TIME_KEY"
    @Published var backupError: String = ""
    @Published var nextBackupTime: String = ""
    
    init(backupsService : BackupsService ) {
        self.backupsService = backupsService
    }
    
    func startBackupTimer(frequency : BackupFrequencyEnum) {
        
        userDefaults.set(frequency.rawValue, forKey: BACKUP_FREQUENCY_KEY)
        backupTimer?.cancel()
        initialTimer?.invalidate()
        
        guard frequency != .manually else { 
            userDefaults.removeObject(forKey: LAST_BACKUP_TIME_KEY)
            return
        }
        
        let interval = frequency.timeInterval
        
        let now = Date()
        var nextBackupDate: Date?
        if let lastBackupTime = userDefaults.object(forKey: LAST_BACKUP_TIME_KEY) as? Date {
            let elapsedTime = now.timeIntervalSince(lastBackupTime)
            let timeUntilNextBackup = interval - elapsedTime.truncatingRemainder(dividingBy: interval)
            nextBackupDate = now.addingTimeInterval(timeUntilNextBackup)
            // Set a one-time timer to perform the next backup
            initialTimer = Timer.scheduledTimer(withTimeInterval: timeUntilNextBackup, repeats: false) { [weak self] _ in
                self?.performBackup()
                self?.startRecurrentBackupTimer(interval: interval)
                self?.displayNextBackupTime(Date().addingTimeInterval(interval))
              
            }
        } else {
            userDefaults.set(Date(), forKey: LAST_BACKUP_TIME_KEY)
            nextBackupDate = now.addingTimeInterval(interval)
            startRecurrentBackupTimer(interval: interval)
        }
        
        if let nextBackupDate = nextBackupDate {
            displayNextBackupTime(nextBackupDate)
        }
    }
    
    func displayNextBackupTime(_ date: Date) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        self.nextBackupTime = dateFormatter.string(from: date)
    }
    
    private func performBackup() {
        Task {
            do {
                await backupsService.loadAllDevices()
                backupsService.loadFoldersToBackup()
                try await backupsService.startBackup { progress in}
                userDefaults.set(Date(), forKey: LAST_BACKUP_TIME_KEY)
                DispatchQueue.main.async {
                    self.backupError = ""
                }
            } catch {
                DispatchQueue.main.async {
                    self.backupError = error.localizedDescription
                }
            }
        }
    }
    
    private func startRecurrentBackupTimer(interval: TimeInterval) {
        backupTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.performBackup()
                self?.displayNextBackupTime(Date().addingTimeInterval(interval))
            }
    }
    
    func resumeBackupScheduler() {
        if let rawValue = UserDefaults.standard.string(forKey: BACKUP_FREQUENCY_KEY),
           let frequency = BackupFrequencyEnum(rawValue: rawValue) {
            startBackupTimer(frequency: frequency)
        }
    }
    
}

