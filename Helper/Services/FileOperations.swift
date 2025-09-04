//
//  FileOperations.swift
//  Helper
//
//  Created by Patricio Tovar on 4/9/25.
//

import Foundation
import os


// MARK: - File Operations Protocol

protocol FileOperationsProtocol {
    func verifyFile(_ path: String, options: CleanupOptions) async -> FileVerification
    func shouldExcludeFile(_ path: String, options: CleanupOptions) async -> Bool
    func deleteFile(at path: String) async throws -> UInt64
}


final class FileOperationsManager: FileOperationsProtocol {
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "FileOperations")
    private let excludedPathsCache = LRUCache<String, Bool>(maxSize: 1000)
    
    func verifyFile(_ path: String, options: CleanupOptions) async -> FileVerification {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return FileVerification(exists: false, canDelete: false, size: 0, shouldSkip: false)
        }
        
        guard !isDirectory.boolValue else {
            return FileVerification(exists: true, canDelete: false, size: 0, shouldSkip: true)
        }
        
        let url = URL(fileURLWithPath: path)
        do {
            let values = try url.resourceValues(forKeys: [.fileAllocatedSizeKey, .isWritableKey])
            let size = UInt64(values.fileAllocatedSize ?? 0)
            let canDelete = values.isWritable ?? false
            
            return FileVerification(exists: true, canDelete: canDelete, size: size, shouldSkip: false)
        } catch {
            return FileVerification(exists: true, canDelete: false, size: 0, shouldSkip: true)
        }
    }
    
    func shouldExcludeFile(_ path: String, options: CleanupOptions) async -> Bool {
        if let cached = await excludedPathsCache.get(path) {
            return cached
        }
        
        let shouldExclude = evaluateExclusionRules(for: path, options: options)
        await excludedPathsCache.set(path, shouldExclude)
        
        return shouldExclude
    }
    
    func deleteFile(at path: String) async throws -> UInt64 {
        let url = URL(fileURLWithPath: path)
        
        // Get file size before deletion
        let resourceValues = try url.resourceValues(forKeys: [.fileAllocatedSizeKey])
        let fileSize = UInt64(resourceValues.fileAllocatedSize ?? 0)
        
        try fileManager.removeItem(at: url)
        logger.debug("File deleted: \(url.lastPathComponent) - \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
        
        return fileSize
    }
    
    private func evaluateExclusionRules(for path: String, options: CleanupOptions) -> Bool {
        let url = URL(fileURLWithPath: path)
        let fileName = url.lastPathComponent
        let parentDirectory = url.deletingLastPathComponent().lastPathComponent
        let fileExtension = url.pathExtension
        
        for rule in options.exclusionRules {
            let pattern = rule.caseSensitive ? rule.pattern : rule.pattern.lowercased()
            let testValue: String
            
            switch rule.type {
            case .fileName:
                testValue = rule.caseSensitive ? fileName : fileName.lowercased()
            case .directoryName:
                testValue = rule.caseSensitive ? parentDirectory : parentDirectory.lowercased()
            case .fullPath:
                testValue = rule.caseSensitive ? path : path.lowercased()
            case .extension:
                testValue = rule.caseSensitive ? fileExtension : fileExtension.lowercased()
            case .regex:
                return evaluateRegexRule(pattern: pattern, testValue: path, caseSensitive: rule.caseSensitive)
            }
            
            if testValue.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func evaluateRegexRule(pattern: String, testValue: String, caseSensitive: Bool) -> Bool {
        do {
            let regexOptions: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
            let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
            let range = NSRange(location: 0, length: testValue.utf16.count)
            return regex.firstMatch(in: testValue, options: [], range: range) != nil
        } catch {
            // Fallback to simple string matching
            let compareValue = caseSensitive ? testValue : testValue.lowercased()
            let comparePattern = caseSensitive ? pattern : pattern.lowercased()
            return compareValue.contains(comparePattern)
        }
    }
    
    func clearCache() async {
        await excludedPathsCache.clear()
    }
}



//
// MARK: - File Scanner
//

final class FileScanner {
    private let fileManager = FileManager.default
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "FileScanner")
    private let fileOperations: FileOperationsProtocol
    private let pathAccessCache = LRUCache<String, Bool>(maxSize: 2000)
    
    // Configuration
    private let maxFilesInMemory: Int
    private let yieldInterval: TimeInterval
    
    init(fileOperations: FileOperationsProtocol,
         maxFilesInMemory: Int = 15_000,
         yieldInterval: TimeInterval = 0.01) {
        self.fileOperations = fileOperations
        self.maxFilesInMemory = maxFilesInMemory
        self.yieldInterval = yieldInterval
    }
    
    func scanFilesInPath(_ path: String,
                        categoryId: String,
                        options: CleanupOptions) async throws -> [CleanupFile] {
        
        guard await isPathAccessible(path) else {
            throw CleanerError.pathNotFound(path: path)
        }
        
        return try await performDirectoryScan(path: path, categoryId: categoryId, options: options)
    }
    
    func calculateDirectorySize(paths: [String], options: CleanupOptions) async throws -> UInt64 {
        var totalSize: UInt64 = 0
        
        for path in paths {
            guard await isPathAccessible(path) else { continue }
            
            let (size, _) = try await calculatePathDetails(at: path, options: options)
            totalSize += size
        }
        
        return totalSize
    }
    
    private func performDirectoryScan(path: String,
                                     categoryId: String,
                                     options: CleanupOptions) async throws -> [CleanupFile] {
        
        return try await Task.detached(priority: .utility) { [fileManager, logger, maxFilesInMemory, yieldInterval] in
            var files: [CleanupFile] = []
            files.reserveCapacity(min(2000, maxFilesInMemory))
            
            let url = URL(fileURLWithPath: path)
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey, .fileAllocatedSizeKey, .nameKey, .isHiddenKey
            ]
            
            var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [
                .skipsPackageDescendants, .producesRelativePathURLs
            ]
            
            if options.skipHiddenFiles {
                enumeratorOptions.insert(.skipsHiddenFiles)
            }
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: enumeratorOptions,
                errorHandler: { url, error in
                    logger.debug("Enumeration error for \(url.lastPathComponent): \(error.localizedDescription)")
                    return true
                }
            ) else {
                throw CleanerError.pathNotFound(path: path)
            }
            
            var lastYieldTime = Date()
            
            while let fileURL = enumerator.nextObject() as? URL {
                let now = Date()
                if now.timeIntervalSince(lastYieldTime) > yieldInterval {
                    await Task.yield()
                    lastYieldTime = now
                    if Task.isCancelled {
                        throw CleanerError.operationCancelled
                    }
                }
                
                if files.count >= maxFilesInMemory {
                    logger.warning("Memory limit reached at \(maxFilesInMemory) files for: \(path)")
                    break
                }
                
                // Depth verification
                if let maxDepth = options.maxDepth {
                    let depth = fileURL.pathComponents.count - url.pathComponents.count
                    if depth > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                
                // File verification and exclusion
                let verification = await self.fileOperations.verifyFile(fileURL.path, options: options)
                if verification.shouldSkip || !verification.exists {
                    continue
                }
                
                if await self.fileOperations.shouldExcludeFile(fileURL.path, options: options) {
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    
                    guard !(resourceValues.isDirectory ?? false) else { continue }
                    
                    let fileSize = verification.size > 0 ? verification.size : UInt64(resourceValues.fileAllocatedSize ?? 0)
                    guard fileSize > 0 else { continue }
                    
                    let file = CleanupFile(
                        id: UUID().uuidString,
                        categoryId: categoryId,
                        name: resourceValues.name ?? fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: fileSize,
                        isDirectory: false,
                        canDelete: verification.canDelete
                    )
                    
                    files.append(file)
                    
                } catch {
                    continue
                }
            }
            
            logger.info("Collected \(files.count) files from \(path)")
            return files
        }.value
    }
    
    private func calculatePathDetails(at path: String, options: CleanupOptions) async throws -> (size: UInt64, fileCount: Int) {
        guard await isPathAccessible(path) else {
            return (0, 0)
        }
        
        return try await Task.detached(priority: .utility) { [fileManager, yieldInterval] in
            var totalSize: UInt64 = 0
            var fileCount: Int = 0
            let url = URL(fileURLWithPath: path)
            
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey, .fileAllocatedSizeKey, .isHiddenKey
            ]
            
            var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [
                .skipsPackageDescendants, .producesRelativePathURLs
            ]
            if options.skipHiddenFiles {
                enumeratorOptions.insert(.skipsHiddenFiles)
            }
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: enumeratorOptions,
                errorHandler: { _, _ in true }
            ) else {
                throw CleanerError.pathNotFound(path: path)
            }
            
            var lastYieldTime = Date()
            
            while let fileURL = enumerator.nextObject() as? URL {
                let now = Date()
                if now.timeIntervalSince(lastYieldTime) > yieldInterval {
                    await Task.yield()
                    lastYieldTime = now
                    if Task.isCancelled {
                        throw CleanerError.operationCancelled
                    }
                }
                
                if let maxDepth = options.maxDepth {
                    let depth = fileURL.pathComponents.count - url.pathComponents.count
                    if depth > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                
                if await self.fileOperations.shouldExcludeFile(fileURL.path, options: options) {
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    
                    if !(resourceValues.isDirectory ?? false) {
                        let fileSize = resourceValues.fileAllocatedSize ?? 0
                        if fileSize > 0 {
                            totalSize += UInt64(fileSize)
                            fileCount += 1
                        }
                    }
                } catch {
                    continue
                }
            }
            
            return (totalSize, fileCount)
        }.value
    }
    
    private func isPathAccessible(_ path: String) async -> Bool {
        if let cached = await pathAccessCache.get(path) {
            return cached
        }
        
        let isAccessible = fileManager.fileExists(atPath: path) &&
                          fileManager.isReadableFile(atPath: path)
        
        await pathAccessCache.set(path, isAccessible)
        return isAccessible
    }
    
    func clearCache() async {
        await pathAccessCache.clear()
    }
}


struct FileVerification {
    let exists: Bool
    let canDelete: Bool
    let size: UInt64
    let shouldSkip: Bool
}
