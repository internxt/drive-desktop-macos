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
            ExclusionRule(type: .directoryName, pattern: "internxt", caseSensitive: false)
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
            return "Permission denied for: \(path)"
        case .pathNotFound(let path):
            return "Path not found: \(path)"
        case .fileInUse(let path):
            return "File in use: \(path)"
        case .internalError(let message):
            return "Internal error: \(message)"
        case .operationCancelled:
            return "Operation was cancelled"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .configurationError(let message):
            return "Configuration error: \(message)"
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
            webCacheCategory(),
            testCategory()
        ]
    }
    
    /// App cache category - Requirement 1
    static func appCacheCategory() -> CleanupCategory {
        return CleanupCategory(
            id: "app_cache",
            name: "Application Cache",
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
    
    /// Log files category - Requirement 1
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
    
    /// Trash category - Requirement 1
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
    
    /// Web storage category - Requirement 1
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
    
    /// Web cache category - Requirement 1
    static func webCacheCategory() -> CleanupCategory {
        let homeDirectory = NSHomeDirectory()
        
        return CleanupCategory(
            id: "web_cache",
            name: "Web Browser Cache",
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
