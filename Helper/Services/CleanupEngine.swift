//
//  CleanupEngine.swift
//  Helper
//
//  Created by Patricio Tovar on 4/9/25.
//

import Foundation
import os


//
// MARK: - Cleanup Engine
//

final class CleanupEngine {
    private let fileOperations: FileOperationsProtocol
    private let scanner: FileScanner
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "CleanupEngine")
    private let concurrencySemaphore: AsyncSemaphore
    
    // Configuration
    private let batchSize: Int
    private let maxConcurrentTasks: Int
    
    init(fileOperations: FileOperationsProtocol,
         scanner: FileScanner,
         maxConcurrentTasks: Int = 8,
         batchSize: Int = 150) {
        self.fileOperations = fileOperations
        self.scanner = scanner
        self.maxConcurrentTasks = min(ProcessInfo.processInfo.processorCount, maxConcurrentTasks)
        self.batchSize = batchSize
        self.concurrencySemaphore = AsyncSemaphore(value: self.maxConcurrentTasks)
    }
    
    func cleanupCategory(_ category: CleanupCategory,
                        options: CleanupOptions,
                        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> CleanupResult {
        
        var errors: [String] = []
        var processedFiles = 0
        var skippedFiles = 0
        var freedSpace: UInt64 = 0
        
        logger.info("Starting cleanup for category: \(category.name)")
        
        await progressHandler(CleanupProgress(
            categoryId: category.id,
            categoryName: category.name,
            currentFile: "Initializing...",
            processedFiles: 0,
            totalFiles: 0,
            freedSpace: 0,
            percentage: 0.0
        ))
        
        let validPaths = category.paths.filter { FileManager.default.fileExists(atPath: $0) }
        
        for (pathIndex, path) in validPaths.enumerated() {
            try Task.checkCancellation()
            
            logger.info("Processing path \(pathIndex + 1)/\(validPaths.count): \(URL(fileURLWithPath: path).lastPathComponent)")
            
            do {
                let result = try await cleanupDirectory(
                    at: path,
                    category: category,
                    options: options,
                    currentProcessed: processedFiles,
                    currentFreed: freedSpace,
                    progressHandler: progressHandler
                )
                
                processedFiles += result.processedFiles
                skippedFiles += result.skippedFiles
                freedSpace += result.freedSpace
                errors.append(contentsOf: result.errors)
                
                let pathProgress = Double(pathIndex + 1) / Double(validPaths.count) * 100
                await progressHandler(CleanupProgress(
                    categoryId: category.id,
                    categoryName: category.name,
                    currentFile: "Path completed: \(URL(fileURLWithPath: path).lastPathComponent)",
                    processedFiles: processedFiles,
                    totalFiles: processedFiles + skippedFiles,
                    freedSpace: freedSpace,
                    percentage: pathProgress
                ))
                
            } catch {
                let errorMessage = "Path cleanup failed \(URL(fileURLWithPath: path).lastPathComponent): \(error.localizedDescription)"
                errors.append(errorMessage)
            }
        }
        
        await progressHandler(CleanupProgress(
            categoryId: category.id,
            categoryName: category.name,
            currentFile: "Category completed",
            processedFiles: processedFiles,
            totalFiles: processedFiles + skippedFiles,
            freedSpace: freedSpace,
            percentage: 100.0
        ))
        
        let success = errors.isEmpty && processedFiles > 0
        
        logger.info("Category '\(category.name)' completed - Success: \(success), Files: \(processedFiles), Freed: \(ByteCountFormatter.string(fromByteCount: Int64(freedSpace), countStyle: .file))")
        
        return CleanupResult(
            categoryId: category.id,
            categoryName: category.name,
            success: success,
            freedSpace: freedSpace,
            errors: errors,
            processedFiles: processedFiles,
            skippedFiles: skippedFiles
        )
    }
    
    func cleanupFiles(_ files: [CleanupFile],
                     categoryId: String,
                     categoryName: String,
                     options: CleanupOptions,
                     progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> CleanupResult {
        
        var errors: [String] = []
        var processedFiles = 0
        var freedSpace: UInt64 = 0
        
        guard !files.isEmpty else {
            return CleanupResult(
                categoryId: categoryId,
                categoryName: categoryName,
                success: true,
                freedSpace: 0,
                errors: [],
                processedFiles: 0,
                skippedFiles: 0
            )
        }
        
        logger.info("Starting cleanup for \(files.count) specific files")
        
        let validFiles = await preValidateFiles(files, options: options)
        logger.info("Pre-validation: \(validFiles.count)/\(files.count) files are valid")
        
        guard !validFiles.isEmpty else {
            return CleanupResult(
                categoryId: categoryId,
                categoryName: categoryName,
                success: false,
                freedSpace: 0,
                errors: ["No valid files to process"],
                processedFiles: 0,
                skippedFiles: files.count
            )
        }
        
        let tracker = ProgressTracker(total: validFiles.count)
        
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: categoryName,
            currentFile: "Starting...",
            processedFiles: 0,
            totalFiles: validFiles.count,
            freedSpace: 0,
            percentage: 0.0
        ))
        
        let optimizedBatchSize = min(batchSize, max(10, validFiles.count / 20))
        
        try await processBatch(validFiles, batchSize: optimizedBatchSize) { file in
            try Task.checkCancellation()
            
            let (shouldUpdate, percentage, currentProcessed) = await tracker.increment()
            
            if shouldUpdate || file.size > 20_000_000 {
                await progressHandler(CleanupProgress(
                    categoryId: categoryId,
                    categoryName: categoryName,
                    currentFile: file.name,
                    processedFiles: currentProcessed,
                    totalFiles: validFiles.count,
                    freedSpace: freedSpace,
                    percentage: percentage
                ))
            }
            
            if options.dryRun {
                self.logger.debug("DRY RUN: Would delete \(file.name) - \(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))")
                processedFiles += 1
                freedSpace += file.size
                return
            }
            
            do {
                guard FileManager.default.fileExists(atPath: file.path) else {
                    self.logger.debug("File no longer exists: \(file.path)")
                    return
                }
                
                let deletedSize = try await self.fileOperations.deleteFile(at: file.path)
                freedSpace += deletedSize
                processedFiles += 1
                
            } catch CocoaError.fileWriteFileExists, CocoaError.fileNoSuchFile {
                self.logger.debug("File already deleted or moved: \(file.name)")
            } catch {
                let errorMessage = "Failed to delete \(file.name): \(error.localizedDescription)"
                errors.append(errorMessage)
                self.logger.warning("❌ \(errorMessage)")
            }
        }
        
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: categoryName,
            currentFile: "Completed",
            processedFiles: processedFiles,
            totalFiles: validFiles.count,
            freedSpace: freedSpace,
            percentage: 100.0
        ))
        
        logger.info("Cleanup completed - Processed: \(processedFiles), Freed: \(ByteCountFormatter.string(fromByteCount: Int64(freedSpace), countStyle: .file))")
        
        return CleanupResult(
            categoryId: categoryId,
            categoryName: categoryName,
            success: errors.isEmpty && processedFiles > 0,
            freedSpace: freedSpace,
            errors: errors,
            processedFiles: processedFiles,
            skippedFiles: validFiles.count - processedFiles
        )
    }
    
    // MARK: - Private Methods
    
    private func cleanupDirectory(
        at path: String,
        category: CleanupCategory,
        options: CleanupOptions,
        currentProcessed: Int,
        currentFreed: UInt64,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> (processedFiles: Int, freedSpace: UInt64, errors: [String], skippedFiles: Int) {
        
        // Get files for this directory
        let files = try await scanner.scanFilesInPath(path, categoryId: category.id, options: options)
        
        // Process the files using the cleanup engine
        let result = try await cleanupFiles(
            files,
            categoryId: category.id,
            categoryName: category.name,
            options: options,
            progressHandler: progressHandler
        )
        
        return (
            processedFiles: result.processedFiles,
            freedSpace: result.freedSpace,
            errors: result.errors,
            skippedFiles: result.skippedFiles
        )
    }
    
    private func processBatch<T>(_ items: [T],
                                batchSize: Int,
                                processor: @escaping @Sendable (T) async throws -> Void) async throws {
        
        for batch in items.chunked(into: batchSize) {
            try Task.checkCancellation()
            
            try await withThrowingTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask {
                        await self.concurrencySemaphore.wait()
                        defer { Task { await self.concurrencySemaphore.signal() } }
                        
                        try await processor(item)
                    }
                }
                
                try await group.waitForAll()
            }
            
            await Task.yield()
        }
    }
    
    private func preValidateFiles(_ files: [CleanupFile], options: CleanupOptions) async -> [CleanupFile] {
        return await withTaskGroup(of: CleanupFile?.self) { group in
            var validFiles: [CleanupFile] = []
            validFiles.reserveCapacity(files.count)
            
            for file in files {
                group.addTask {
                    await self.concurrencySemaphore.wait()
                    defer { Task { await self.concurrencySemaphore.signal() } }
                    
                    let verification = await self.fileOperations.verifyFile(file.path, options: options)
                    return verification.exists && !verification.shouldSkip ? file : nil
                }
            }
            
            for await validFile in group {
                if let file = validFile {
                    validFiles.append(file)
                }
            }
            
            return validFiles
        }
    }
}
