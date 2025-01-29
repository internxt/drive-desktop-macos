//
//  AntivirusManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 20/1/25.
//

import Foundation
import InternxtSwiftCore
import SwiftUI

class AntivirusManager: ObservableObject {
    @Published var currentState: ScanState = .locked
    @Published var scannedFiles: Int = 0
    @Published var detectedFiles: Int = 0
    @Published var progress: Double = 0.0
    @Published var showAntivirus: Bool = false
    @Published var infectedFiles: [FileItem] = []
    @Published var selectedPath: String = ""

    var scanProcess: Process?
    
    @MainActor
    func fetchAntivirusStatus() async {
        do {
            appLogger.info("Antivirus Information")
            if self.currentState != .scanning {
                let paymentInfo = try await APIFactory.Payment.getPaymentInfo(debug: true)
                self.currentState = paymentInfo.featuresPerService.antivirus ? .options : .locked
            }
        }
        catch {
            
            guard let apiError = error as? APIClientError else {
                appLogger.info(error.getErrorDescription())
                return
            }
            appLogger.info(error.getErrorDescription())
            if(apiError.statusCode == 404) {
                self.currentState = .locked
            }
        }
    }
    
    func startScan(path: String) {
        infectedFiles = []
        currentState = .scanning
        progress = 0
        scannedFiles = 0
        detectedFiles = 0
        
        countFilesInDirectoryAsync(at: path) { [weak self] initialTotalFiles in
            guard let self = self else { return }
            
            
            if initialTotalFiles == 0 {
                DispatchQueue.main.async {
                    self.currentState = .results(noThreats: true)
                    self.showAlert(message: "There are no files to scan")
                }
                return
            }
            
            var totalFiles = initialTotalFiles
                        
            self.scanPathWithClamAVAndProgress(
                path: path,
                onProgress: { [weak self] scannedCount, lineInfo in
                    guard let self = self else { return }
                    
                    DispatchQueue.main.async {
                        self.scannedFiles = scannedCount
                        
                        if scannedCount > totalFiles {
                            totalFiles = scannedCount
                        }
                        let progressPercentage = Double(scannedCount) / Double(totalFiles) * 100.0
                        if Int(progressPercentage) % 10 == 0 {
                            self.progress = progressPercentage
                        }
                        self.selectedPath = lineInfo
                    }
                },
                onInfected: { [weak self] lineInfo in
                    guard let self = self else { return }
                    
                    let parts = lineInfo.components(separatedBy: ": ")
                    if !parts.isEmpty {
                        let infectedPath = parts[0]
                        let fileItem = createFileItem(for: infectedPath)
                        DispatchQueue.main.async {
                            self.selectedPath = infectedPath
                            self.infectedFiles.append(fileItem)
                            self.detectedFiles += 1
                        }
                    }
                },
                onComplete: { [weak self] success in
                    guard let self = self else { return }
                    DispatchQueue.main.async {
                        self.currentState = .results(noThreats: (self.detectedFiles == 0))
                        if self.detectedFiles == 0 {
                            if let resolvedURL = BookmarkManager.shared.resolveBookmark() {
                                 BookmarkManager.shared.stopAccessing(url: resolvedURL)
                                appLogger.info("Bookmark released")
                             }
                        }
                    }
                }
            )
        }
    }
    
    func scanPathWithClamAVAndProgress(
        path: String,
        onProgress: @escaping (_ scannedCount: Int, _ lineInfo: String) -> Void,
        onInfected: @escaping (_ lineInfo: String) -> Void,
        onComplete: @escaping (Bool) -> Void
    ) {
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            guard let clamscanURL = Bundle.main.url(
                forResource: "clamscan",
                withExtension: nil,
                subdirectory: "ClamAVResources"
            ) else {
                appLogger.error("clamscan not found")
                onComplete(false)
                return
            }
            
            let databaseDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent("ClamAV/database")
            
            guard FileManager.default.fileExists(atPath: databaseDir.path) else {
                appLogger.error("DB Directory not found: \(databaseDir.path)")
                onComplete(false)
                return
            }
            
            let fileManager = FileManager.default
            var isDir: ObjCBool = false
            _ = fileManager.fileExists(atPath: path, isDirectory: &isDir)
            
            let process = Process()
            process.executableURL = clamscanURL
            
            var arguments = [
                "--database=\(databaseDir.path)",
                "--no-summary",
                "-v"
            ]
            if isDir.boolValue {
                arguments.append("-r")
            }
            arguments.append(path)
            process.arguments = arguments
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            var scannedCount = 0
            
            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let data = fileHandle.availableData
                guard !data.isEmpty else {
                    return
                }
                
                let outputChunk = String(data: data, encoding: .utf8) ?? ""
                let lines = outputChunk.components(separatedBy: .newlines)
                for line in lines {
                    guard !line.isEmpty else { continue }
                    if line.contains("FOUND") {
                        scannedCount += 1
                        onInfected(line)
                        onProgress(scannedCount, line)
                    } else if line.contains(": ") {
                        scannedCount += 1
                        onProgress(scannedCount, line)
                    }
                }
            }
            
            process.terminationHandler = { [weak self] _ in
                guard let self = self else { return }
                pipe.fileHandleForReading.readabilityHandler = nil
                
                let exitCode = process.terminationStatus
                
                DispatchQueue.main.async {
                    switch exitCode {
                    case 0:
                        onComplete(true)
                    case 1:
                        appLogger.warning("Scan completed, infections found.")
                        onComplete(true)
                    case 2:
                        appLogger.error("Error during scan.")
                        onComplete(false)
                    default:
                        appLogger.error("Unknown exit code: \(exitCode)")
                        onComplete(false)
                    }
                    
                    self.scanProcess = nil
                }
            }
            
            do {
                self.scanProcess = process
                try process.run()
            } catch {
                appLogger.error(error.localizedDescription)
                onComplete(false)
                self.scanProcess = nil
            }
            
        }
    }

    
    func cancelScan() {
          DispatchQueue.global(qos: .background).async { [weak self] in
              guard let self = self else { return }
              if let process = self.scanProcess {
                  process.terminate()
                  self.scanProcess = nil
                  DispatchQueue.main.async {
                      self.currentState = .results(noThreats: (self.detectedFiles == 0))
                      appLogger.info("Process cancel by user")
                  }
              }
          }
      }
    
    func createFileItem(for filePath: String) -> FileItem {
        let fileURL = URL(fileURLWithPath: filePath)
        let fileName = fileURL.lastPathComponent
        let fileExtension = fileURL.pathExtension.lowercased()
        let iconName: String
        switch fileExtension {
            // Word
        case "doc", "docx":
            iconName = "word"
            
            // Excel
        case "xls", "xlsx", "xlsm":
            iconName = "xls"
            
            // PowerPoint
        case "ppt", "pptx", "pps", "ppsx":
            iconName = "powerpoint"
            
            // Illustrator
        case "ai":
            iconName = "illustrator"
            
            // png, jpg, jpeg, gif
        case "png", "jpg", "jpeg", "gif":
            iconName = "image"
            
        default:
            iconName = "default"
        }
        
        return FileItem(iconName: iconName, fileName: fileName, extensionType: fileExtension, fullPath: filePath)
    }
    
    func removeInfectedFiles(_ files: [FileItem]) throws {
        let fileManager = FileManager.default
        
        for fileItem in files {
            let fileURL = URL(fileURLWithPath: fileItem.fullPath)
            try fileManager.removeItem(at: fileURL)
            appLogger.info("File delete successful : \(fileURL)")
        }
    }
    
    func updateClamAVDatabase(usingFreshclam freshclamURL: URL, configPath: String, databaseDir: String, onComplete: @escaping (Bool) -> Void) {
        
        DispatchQueue.global(qos: .background).async {
            
            let process = Process()
            process.executableURL = freshclamURL
            process.arguments = ["--config-file=\(configPath)"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            pipe.fileHandleForReading.readabilityHandler = { fileHandle in
                let output = String(data: fileHandle.availableData, encoding: .utf8) ?? ""
                
                if output.contains("Downloading daily.cvd") || output.contains("Downloading main.cvd") {
                    // download
                } else if output.contains("Your ClamAV database is up to date.") {
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
    
    
    
    func downloadDatabases() {
        appLogger.info("Download databases")
        if self.currentState == .locked {
            appLogger.info("Status is locked")
            return
        }
        
        let fileManager = FileManager.default
        let appSupportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let clamAVDir = appSupportDir.appendingPathComponent("ClamAV")
        let databaseDir = clamAVDir.appendingPathComponent("database")
        let freshclamConfigPath = clamAVDir.appendingPathComponent("freshclam.conf")
        
        try? fileManager.createDirectory(at: databaseDir, withIntermediateDirectories: true)
        
        
        if isDatabaseUpToDate(databaseDir: databaseDir) {
            appLogger.info("Databases are up to date")
            return
        }
        
        clearDatabaseDirectory(databaseDir: databaseDir)
        
        
        
        // Generate freshclam.conf
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
        let databaseFiles = ["main.cvd", "daily.cvd", "bytecode.cvd"]
        
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
                
                // Check update from file
                if let difference = calendar.dateComponents([.day], from: modificationDate, to: currentDate).day, difference > 5 {
                    appLogger.info("\(fileName) is not updated. Last modification: \(modificationDate).")
                    return false
                }
            } else {
                appLogger.info("Failed to get file attributes\(fileName).")
                return false
            }
        }
        
        return true
    }
    
    
    func clearDatabaseDirectory(databaseDir: URL) {
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
    
    func countFilesInDirectoryAsync(at directoryPath: String, completion: @escaping (Int) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let fileManager = FileManager.default
            var isDirectory: ObjCBool = false

            if fileManager.fileExists(atPath: directoryPath, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    DispatchQueue.main.async {
                        completion(1)
                    }
                    return
                }
            } else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }
            let baseURL = URL(fileURLWithPath: directoryPath)
            guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: nil,
                                                          options: [.skipsHiddenFiles]) else {
                DispatchQueue.main.async {
                    completion(0)
                }
                return
            }
            
            var fileCount = 0
            for case let fileURL as URL in enumerator {
                if !fileURL.hasDirectoryPath {
                    fileCount += 1
                }
            }
            
            DispatchQueue.main.async {
                completion(fileCount)
            }
        }
    }
    
    func showAlert(message: String, informativeText: String? = nil, style: NSAlert.Style = .informational, buttonTitle: String = "OK") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText ?? ""
        alert.alertStyle = style
        alert.addButton(withTitle: buttonTitle)
        alert.runModal()
    }
    
}
