//
//  LogService.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 19/3/24.
//

import Foundation
import CocoaLumberjackSwift

enum LogSubSystem: String {
    case SyncExtension = "com.internxt.SyncExtension"
    case InternxtDesktop = "com.internxt.InternxtDesktop"
    case XPCBackups = "com.internxt.XPCBackups"
    case Errors = "com.internxt.errors"
    case SyncExtensionWorkspace = "com.internxt.SyncExtension.Workspace"
}

class DDLoggerWrapper {
    private let subsystem: LogSubSystem
    private let category: String
    private let logger: DDLog

    init(subsystem: LogSubSystem, category: String, fileLogger: DDFileLogger?) {
        self.subsystem = subsystem
        self.category = category
        self.logger = DDLog()

        if let fileLogger = fileLogger {
            fileLogger.logFormatter = InternxtLogFormatter()
            fileLogger.maximumFileSize = 500 * 1024 * 1024
            fileLogger.logFileManager.maximumNumberOfLogFiles = 2
            fileLogger.rollingFrequency = 0
            
            self.logger.add(fileLogger, with: .all)
        }

        let osLogger = DDOSLogger.sharedInstance
        osLogger.logFormatter = InternxtLogFormatter()
        self.logger.add(osLogger)
    }


    func debug(_ message: @autoclosure () -> Any, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .debug, flag: .debug, file: file, function: function, line: line)
    }

    func info(_ message: @autoclosure () -> Any, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .info, flag: .info, file: file, function: function, line: line)
    }

    func warning(_ message: @autoclosure () -> Any, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .warning, flag: .warning, file: file, function: function, line: line)
    }

    func error(_ message: @autoclosure () -> Any, file: StaticString = #file, function: StaticString = #function, line: UInt = #line) {
        log(message(), level: .error, flag: .error, file: file, function: function, line: line)
    }


    private func log(_ message: Any, level: DDLogLevel, flag: DDLogFlag, file: StaticString, function: StaticString, line: UInt) {
        let formattedMessage = "[\(subsystem.rawValue)] [\(category)] \(message)"
        
        let logMessage = DDLogMessage(
            message: formattedMessage,
            level: level,
            flag: flag,
            context: 0,
            file: "\(file)",
            function: "\(function)",
            line: line,
            tag: nil,
            options: [],
            timestamp: Date()
        )
        logger.log(asynchronous: true, message: logMessage)
    }
}

final class LogService {
    static var shared = LogService()
    
    func getLogsDirectory() -> URL? {
        let fileManager = FileManager.default
        if let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: INTERNXT_GROUP_NAME) {
            let logsDirectory = groupURL.appendingPathComponent("Logs")
            
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: logsDirectory.path, isDirectory: &isDirectory) {
                if !isDirectory.boolValue {
                    return nil
                }
            } else {
                do {
                    try fileManager.createDirectory(at: logsDirectory, withIntermediateDirectories: true, attributes: nil)
                } catch {
                    return nil
                }
            }
            
            if !fileManager.isWritableFile(atPath: logsDirectory.path) {
                return nil
            }
            
            return logsDirectory
        }
        return nil
    }
    
    func createLogger(subsystem: LogSubSystem, category: String) -> DDLoggerWrapper {
        let fileLogger = createFileLogger(for: subsystem)
        return DDLoggerWrapper(subsystem: subsystem, category: category, fileLogger: fileLogger)
    }
    
    private func createFileLogger(for subsystem: LogSubSystem) -> DDFileLogger? {
        guard let logsDirectory = getLogsDirectory() else {
            print("LogService Warning: cannot get logs directory")
            return nil
        }


        let fileManager = InternxtLogFileManager(logsDirectory: logsDirectory.path, subsystem: subsystem)
        let fileLogger = DDFileLogger(logFileManager: fileManager)
        
        fileLogger.maximumFileSize = 500 * 1024 * 1024
        fileLogger.rollingFrequency = 0
        fileLogger.logFileManager.maximumNumberOfLogFiles = 2
        
        return fileLogger
    }
    
}


class InternxtLogFileManager: DDLogFileManagerDefault {
    private let subsystem: LogSubSystem
    
    init(logsDirectory: String, subsystem: LogSubSystem) {
        self.subsystem = subsystem
        super.init(logsDirectory: logsDirectory)
    }
    
    override var newLogFileName: String {
      
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = formatter.string(from: Date())
        return "\(subsystem.rawValue)_\(timestamp).log"
    }
    
    override func isLogFile(withName fileName: String) -> Bool {
        return (fileName.hasPrefix(subsystem.rawValue) && fileName.hasSuffix(".log"))
    }
}

class InternxtLogFormatter: NSObject, DDLogFormatter {
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 2 * 3600)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    func format(message logMessage: DDLogMessage) -> String? {
        let timestamp = dateFormatter.string(from: logMessage.timestamp)
        let level = levelString(from: logMessage.flag)
        let filename = URL(fileURLWithPath: logMessage.file).lastPathComponent
        let line = logMessage.line
        
        return "[\(timestamp)] [\(level)] [\(filename):\(line)] \(logMessage.message)"
    }
    
    private func levelString(from flag: DDLogFlag) -> String {
        switch flag {
        case .error: return "ERROR"
        case .warning: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        default: return "UNKNOWN"
        }
    }
}


let syncExtensionLogger = LogService.shared.createLogger(subsystem: .SyncExtension, category: "SyncExtension")
let appLogger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "InternxtDesktopUIApp")
let syncExtensionWorkspaceLogger = LogService.shared.createLogger(subsystem: .SyncExtensionWorkspace, category: "SyncExtensionWorkspace")
