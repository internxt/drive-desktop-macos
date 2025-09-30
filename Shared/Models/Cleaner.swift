//
//  Cleaner.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 27/8/25.
//

import Foundation

// MARK: - Data Models

struct CleanupCategory: Codable, Equatable {
    let id: String
    let name: String
    let paths: [String]
    var size: UInt64 = 0
    var isSelected: Bool = false
    var canAccess: Bool = true
    var errorMessage: String?
}

struct CleanupResult: Codable {
    let categoryId: String
    let categoryName: String
    let success: Bool
    let freedSpace: UInt64
    let errors: [String]
    let processedFiles: Int
    let skippedFiles: Int
}

struct CleanupProgress: Codable {
    let categoryId: String
    let categoryName: String
    let currentFile: String
    let processedFiles: Int
    let totalFiles: Int
    let freedSpace: UInt64
    let percentage: Double
}

struct ScanResult: Codable {
    let categories: [CleanupCategory]
    let totalSize: UInt64
    let scanDuration: TimeInterval
    let accessiblePaths: Int
    let inaccessiblePaths: Int
}

struct PathScanResult: Codable {
    let path: String
    let size: UInt64
    let canAccess: Bool
    let error: String?
    let fileCount: Int
}

// MARK: - Configuration Models

struct ExclusionRule: Codable {
    let type: ExclusionType
    let pattern: String
    let caseSensitive: Bool
    
    enum ExclusionType: String, Codable {
        case fileName
        case directoryName
        case fullPath
        case `extension`
        case regex
    }
}

struct CleanupOptions: Codable {
    let exclusionRules: [ExclusionRule]
    let skipHiddenFiles: Bool
    let skipSystemFiles: Bool
    let maxDepth: Int?
    let dryRun: Bool
    
    static let `default` = CleanupOptions(
        exclusionRules: [
            ExclusionRule(type: .fileName, pattern: "Internxt", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "internxt", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "LaunchServices", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "iconservices", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "Spotlight", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "Spotlight", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "CloudKit", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "CloudKit", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "icloud", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "kext", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "kernel", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "boot", caseSensitive: false),

            ExclusionRule(type: .fileName, pattern: ".csstore", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "com.apple.iconservices.store", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "com.apple.bird", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "com.apple.kext.caches", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "com.apple.kernelcaches", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "preboot", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "com.apple.preboot", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "TouchIconCache", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "CrashReporter", caseSensitive: false),
            ExclusionRule(type: .directoryName, pattern: "DiagnosticReports", caseSensitive: false),

            ExclusionRule(type: .extension, pattern: "tmp", caseSensitive: false),
            ExclusionRule(type: .extension, pattern: "lock", caseSensitive: false),
            ExclusionRule(type: .extension, pattern: "pid", caseSensitive: false),
            ExclusionRule(type: .extension, pattern: "kext", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "plist", caseSensitive: false),
            ExclusionRule(type: .regex, pattern: ".*kernel.*", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "boot", caseSensitive: false),
            ExclusionRule(type: .fileName, pattern: "bird", caseSensitive: false),



        ],
        skipHiddenFiles: true,
        skipSystemFiles: true,
        maxDepth: nil,
        dryRun: false
    )
}
// MARK: - Error Types

enum CleanerError: Error, LocalizedError {
    case permissionDenied(path: String)
    case pathNotFound(path: String)
    case fileInUse(path: String)
    case internalError(String)
    case operationCancelled
    case invalidData(String)
    case configurationError(String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied(let path):
            return String(format: NSLocalizedString("CLEANER_ERROR_PERMISSION_DENIED", comment: "Error message for permission denied"), path)
        case .pathNotFound(let path):
            return String(format: NSLocalizedString("CLEANER_ERROR_PATH_NOT_FOUND", comment: "Error message for path not found"), path)
        case .fileInUse(let path):
            return String(format: NSLocalizedString("CLEANER_ERROR_FILE_IN_USE", comment: "Error message for file in use"), path)
        case .internalError(let message):
            return String(format: NSLocalizedString("CLEANER_ERROR_INTERNAL_ERROR", comment: "Error message for internal error"), message)
        case .operationCancelled:
            return NSLocalizedString("CLEANER_ERROR_OPERATION_CANCELLED", comment: "Error message for operation cancelled")
        case .invalidData(let message):
            return String(format: NSLocalizedString("CLEANER_ERROR_INVALID_DATA_MESSAGE", comment: "Error message for invalid data"), message)
        case .configurationError(let message):
            return String(format: NSLocalizedString("CLEANER_ERROR_CONFIGURATION_ERROR", comment: "Error message for configuration error"), message)
        }
    }
}



struct CleanerCategories {
    
    /// Get all predefined cleanup categories
    static func getAllCategories() -> [CleanupCategory] {
        return [
            appCacheCategory(),
            logFilesCategory(),
            trashCategory(),
            webStorageCategory(),
            webCacheCategory()
        ]
    }
    
 
    static func appCacheCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "app_cache",
            name: "App Cache",
            paths: [
                NSHomeDirectory() + "/Library/Caches",
                "/System/Library/Caches",
                "/Library/Caches"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
    
 
    static func logFilesCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "log_files",
            name: "Log Files",
            paths: [
                NSHomeDirectory() + "/Library/Logs",
                "/var/log",
                "/Library/Logs"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
    
 
    static func trashCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "trash",
            name: "Trash",
            paths: [
                NSHomeDirectory() + "/.Trash"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
    
    static func testCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "test",
            name: "Test",
            paths: [
                NSHomeDirectory() + "/Documents/test"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
    
    static func webStorageCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "web_storage",
            name: "Web Storage",
            paths: [
                NSHomeDirectory() + "/Library/HTTPStorages",
                NSHomeDirectory() + "/Library/Cookies",
                NSHomeDirectory() + "/Library/Safari/LocalStorage"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
    

    static func webCacheCategory() -> CleanupCategory {
        let homeDirectory = NSHomeDirectory()
        
        return CleanupCategory(
            id: "web_cache",
            name: "Web Cache",
            paths: [
                homeDirectory + "/Library/Caches/com.apple.Safari",
                homeDirectory + "/Library/Caches/Google/Chrome",
                homeDirectory + "/Library/Caches/com.google.Chrome",
                homeDirectory + "/Library/Caches/org.mozilla.firefox",
                homeDirectory + "/Library/Caches/com.microsoft.edgemac",
                homeDirectory + "/Library/Caches/com.operasoftware.Opera"
            ],
            size: 0,
            isSelected: false,
            canAccess: true,
            errorMessage: nil
        )
    }
}



struct CleanupFile: Codable, Identifiable {
    let id: String
    let categoryId: String
    let name: String
    let path: String
    let size: UInt64
    let isDirectory: Bool
    let canDelete: Bool
    
    var formattedSize: String {
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
    
    var fileExtension: String {
        return URL(fileURLWithPath: path).pathExtension
    }
}


enum CleanupType : Codable {
    case categoriesOnly([CleanupCategory])
    case filesOnly([String: [CleanupFile]])
    case hybrid([CleanupCategory], [String: [CleanupFile]])
}

struct CleanupData : Codable {
    let type: CleanupType
}


enum CleanerServiceError: LocalizedError {
    case connectionFailed
    case helperNotAvailable
    case scanFailed(underlying: Error)
    case cleanupFailed(underlying: Error)
    case operationNotFound
    case invalidData
    case connectionTimeout
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return NSLocalizedString("CLEANER_ERROR_CONNECTION_FAILED", comment: "Error message for connection failed")
        case .helperNotAvailable:
            return NSLocalizedString("CLEANER_ERROR_HELPER_NOT_AVAILABLE", comment: "Error message for helper not available")
        case .scanFailed(let error):
            return String(format: NSLocalizedString("CLEANER_ERROR_SCAN_FAILED", comment: "Error message for scan failed"), error.localizedDescription)
        case .cleanupFailed(let error):
            return String(format: NSLocalizedString("CLEANER_ERROR_CLEANUP_FAILED", comment: "Error message for cleanup failed"), error.localizedDescription)
        case .operationNotFound:
            return NSLocalizedString("CLEANER_ERROR_OPERATION_NOT_FOUND", comment: "Error message for operation not found")
        case .invalidData:
            return NSLocalizedString("CLEANER_ERROR_INVALID_DATA", comment: "Error message for invalid data")
        case .connectionTimeout:
            return NSLocalizedString("CLEANER_ERROR_CONNECTION_TIMEOUT", comment: "Error message for connection timeout")
        }
    }
}

enum CleanerState: Equatable {
    case idle
    case connecting
    case scanning(progress: Double?)
    case cleaning(progress: CleanupProgress?)
    case completed
    case error(String)
    case cancelling
    case cancelled
    
    var isLoading: Bool {
        switch self {
        case .connecting, .scanning, .cleaning:
            return true
        default:
            return false
        }
    }
    static func == (lhs: CleanerState, rhs: CleanerState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.connecting, .connecting), (.completed, .completed):
            return true
        case let (.scanning(lProgress), .scanning(rProgress)):
            return lProgress == rProgress
        case let (.cleaning(lProgress), .cleaning(rProgress)):
            if let lProg = lProgress, let rProg = rProgress {
                return lProg.percentage == rProg.percentage &&
                       lProg.processedFiles == rProg.processedFiles &&
                       lProg.totalFiles == rProg.totalFiles
            }
            return lProgress == nil && rProgress == nil
        case let (.error(lMessage), .error(rMessage)):
            return lMessage == rMessage
        default:
            return false
        }
    }
}
