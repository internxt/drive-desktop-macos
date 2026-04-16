//
//  ClamAVDatabaseService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 1/4/26.
//

import Foundation
import InternxtSwiftCore

class ClamAVDatabaseService {
    
    static let shared = ClamAVDatabaseService()
    
    var databaseDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClamAV/database")
    }
    
    var clamAVDir: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClamAV")
    }
    
  
    
    func downloadDatabasesIfNeeded(currentState: ScanState) {
        appLogger.info("Download databases")
        if currentState == .locked {
            appLogger.info("Status is locked")
            return
        }
        
        let fileManager = FileManager.default
        let freshclamConfigPath = clamAVDir.appendingPathComponent("freshclam.conf")
        
        try? fileManager.createDirectory(at: databaseDir, withIntermediateDirectories: true)
        
        if isDatabaseUpToDate(databaseDir: databaseDir) {
            appLogger.info("Databases are up to date")
            return
        }
        
        clearDatabaseDirectory(databaseDir: databaseDir)
        
        do {
            try """
            # freshclam.conf
            DatabaseDirectory \(databaseDir.path)
            DatabaseMirror database.clamav.net
            Checks 24
            """.write(toFile: freshclamConfigPath.path, atomically: true, encoding: .utf8)
        } catch {
            appLogger.error("Error generating freshclam.conf: \(error.localizedDescription)")
            return
        }
        
        guard let freshclamURL = Bundle.main.url(forResource: "freshclam", withExtension: nil, subdirectory: "ClamAVResources") else {
            appLogger.error("freshclam not found")
            return
        }
        
        updateClamAVDatabase(usingFreshclam: freshclamURL, configPath: freshclamConfigPath.path, databaseDir: databaseDir.path) { success in
            if !success {
                appLogger.error("Error updating databases")
            }
        }
    }
    
    func isDatabaseUpToDate(databaseDir: URL) -> Bool {
        let fileManager = FileManager.default
        let databaseFiles = ["main.cvd", "bytecode.cvd"]
        let dailyFileOptions = ["daily.cvd", "daily.cld"]
        
        for fileName in databaseFiles {
            let filePath = databaseDir.appendingPathComponent(fileName)
            if !fileManager.fileExists(atPath: filePath.path) {
                appLogger.info("\(fileName) not found.")
                return false
            }
            
            if let attributes = try? fileManager.attributesOfItem(atPath: filePath.path),
               let modificationDate = attributes[.modificationDate] as? Date {
                let currentDate = Date()
                let calendar = Calendar.current
                if let difference = calendar.dateComponents([.day], from: modificationDate, to: currentDate).day, difference > 5 {
                    appLogger.info("\(fileName) is not updated. Last modification: \(modificationDate).")
                    return false
                }
            } else {
                appLogger.info("Failed to get file attributes for \(fileName).")
                return false
            }
        }
        
        var dailyFileFound = false
        var dailyFileDate: Date?
        
        for dailyFileName in dailyFileOptions {
            let dailyFilePath = databaseDir.appendingPathComponent(dailyFileName)
            if fileManager.fileExists(atPath: dailyFilePath.path) {
                dailyFileFound = true
                if let attributes = try? fileManager.attributesOfItem(atPath: dailyFilePath.path),
                   let modificationDate = attributes[.modificationDate] as? Date {
                    dailyFileDate = modificationDate
                }
                break
            }
        }
        
        if !dailyFileFound {
            appLogger.info("Daily database file not found (tried \(dailyFileOptions.joined(separator: ", "))).")
            return false
        }
        
        if let modificationDate = dailyFileDate {
            let currentDate = Date()
            let calendar = Calendar.current
            if let difference = calendar.dateComponents([.day], from: modificationDate, to: currentDate).day, difference > 5 {
                appLogger.info("Daily database file is not updated. Last modification: \(modificationDate).")
                return false
            }
        }
        
        return true
    }
    
 
    
    private func updateClamAVDatabase(usingFreshclam freshclamURL: URL, configPath: String, databaseDir: String, onComplete: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let process = Process()
            process.executableURL = freshclamURL
            process.arguments = ["--config-file=\(configPath)"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let output = String(data: fileHandle.availableData, encoding: .utf8) ?? ""
                if output.contains("Your ClamAV database is up to date.") {
                    appLogger.info("Databases are up to date")
                }
            }
            
            process.terminationHandler = { _ in
                let exitCode = process.terminationStatus
                DispatchQueue.main.async {
                    if exitCode == 0 {
                        appLogger.info("Databases update successfully \(databaseDir).")
                        onComplete(true)
                    } else {
                        appLogger.error("Error updating databases: \(exitCode)")
                        onComplete(false)
                    }
                }
            }
            
            do {
                try process.run()
            } catch {
                appLogger.error("Error executing freshclam: \(error.localizedDescription)")
                onComplete(false)
            }
        }
    }
    
    private func clearDatabaseDirectory(databaseDir: URL) {
        let fileManager = FileManager.default
        do {
            let files = try fileManager.contentsOfDirectory(atPath: databaseDir.path)
            for file in files {
                let filePath = databaseDir.appendingPathComponent(file)
                try fileManager.removeItem(at: filePath)
            }
        } catch {
            appLogger.error("Error cleaning database directory: \(error.localizedDescription)")
        }
    }
}
