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
    case Errors = "com.internxt.errors"
    case SyncExtensionWorkspace = "com.internxt.SyncExtension.Workspace"
}

struct LogService {
    static var shared = LogService()
    
    func getLogsDirectory() -> URL? {
        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: INTERNXT_GROUP_NAME) {
            let logsDirectory = groupURL.appendingPathComponent("Logs")
            try? fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
            
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
        systemDestination.showFunctionName = false
        systemDestination.showThreadName = false
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true
        
        log.dateFormatter = {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 2 * 3600)
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
            return formatter
        }()
        
        log.add(destination: systemDestination)
        
        guard let logsDirectoryUnwrapped = logsDirectory else {
            return log
        }
        
        let logFile = logsDirectoryUnwrapped.appendingPathComponent("\(subsystem.rawValue).log")
        
        let fileDestination = AutoRotatingFileDestination(
            writeToFile: logFile,
            identifier: "\(subsystem.rawValue).\(category).fileDestination",
            shouldAppend: true,
            maxFileSize: 1000 * 1024 * 1024,
            targetMaxLogFiles: 1
        )
   
        
        
        fileDestination.outputLevel = .debug
        fileDestination.showLogIdentifier = false
        fileDestination.showThreadName = false
        fileDestination.showFunctionName = false
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showDate = true
        
        fileDestination.logQueue = DispatchQueue.global(qos: .background)
     
        log.add(destination: fileDestination)
    
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

let syncExtensionLogger = LogService.shared.createLogger(subsystem: .SyncExtension, category: "SyncExtension")
let appLogger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "InternxtDesktopUIApp")
let syncExtensionWorkspaceLogger = LogService.shared.createLogger(subsystem: .SyncExtensionWorkspace, category: "SyncExtensionWorkspace")
