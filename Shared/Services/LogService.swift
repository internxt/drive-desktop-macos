//
//  LogService.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 19/3/24.
//

import Foundation
import XCGLogger


enum LogSubSystem: String {
    case SyncExtension = "com.internxt.SyncExtension"
    case InternxtDesktop = "com.internxt.InternxtDesktop"
    case XPCBackups = "com.internxt.XPCBackups"
}

struct LogService {
    static var shared = LogService()
    
    func getLogsDirectory() -> URL? {
        let fileManager = FileManager.default
        if let libraryDirectory = fileManager.urls(for: .allLibrariesDirectory, in: .userDomainMask).first {
            let logsDirectory = libraryDirectory.appendingPathComponent("Logs")
            return logsDirectory
        }
        return nil
        
    }
    
   
    
    
    func createLogger(subsystem: LogSubSystem, category: String) -> XCGLogger {
        let logsDirectory = getLogsDirectory()
        
        
        
        let log = XCGLogger(identifier: subsystem.rawValue, includeDefaultDestinations: false)
        
        let systemDestination = AppleSystemLogDestination(identifier: "\(subsystem).\(category).systemDestination")

        systemDestination.outputLevel = .debug
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = false
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true


        log.add(destination: systemDestination)


        guard let logsDirectoryUnwrapped = logsDirectory else {
            log.logAppDetails()
            return log
        }
        
        
        let logFile = logsDirectoryUnwrapped.appendingPathComponent("\(subsystem.rawValue).log")
        
        let fileDestination = FileDestination(writeToFile: logFile, identifier: "\(subsystem.rawValue).\(category).fileDestination", shouldAppend: true)

        fileDestination.outputLevel = .debug
        fileDestination.showLogIdentifier = false
        fileDestination.showThreadName = false
        fileDestination.showFunctionName = true
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showDate = true
        fileDestination.logQueue = DispatchQueue.global(qos: .background)


        log.add(destination: fileDestination)
        
        log.logAppDetails()
        return log
    }
    
    private func createDirectoryIfNeeded(at url: URL) -> Bool {
        let fileManager = FileManager.default
            do {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
                return true
            } catch {
                return false
            }
    }
    
    private func createFileIfNeeded(at url: URL) -> Bool {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: url.path) {
            return fileManager.createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        
        return true
    }
 }
