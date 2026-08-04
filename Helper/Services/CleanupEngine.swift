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
                    progressHandler: progressHandler
                )
                
                processedFiles += result.processedFiles
                skippedFiles += result.skippedFiles
                freedSpace += result.freedSpace
                errors.append(contentsOf: result.errors)
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
                     categorySize: UInt64 = 0,
                     baseProcessedCount: Int = 0,
                     baseFreedSpace: UInt64 = 0,
                     progressHandler: @escaping @Sendable (CleanupProgress) async -> Void) async throws -> CleanupResult {
        
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
        
        let pathTotal = baseProcessedCount + validFiles.count
        let tracker = ProgressTracker(total: validFiles.count)
        let initialPercentage = categorySize > 0 ? min(Double(baseFreedSpace) / Double(categorySize) * 100.0, 99.0) : (pathTotal > 0 ? min(Double(baseProcessedCount) / Double(pathTotal) * 100.0, 99.0) : 0.0)
        
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: categoryName,
            currentFile: "Scanning files...",
            processedFiles: baseProcessedCount,
            totalFiles: pathTotal,
            freedSpace: baseFreedSpace,
            percentage: initialPercentage
        ))
        
        let optimizedBatchSize = min(batchSize, max(10, validFiles.count / 20))
        
        try await processBatch(validFiles, batchSize: optimizedBatchSize) { file in
            try Task.checkCancellation()
            
            if options.dryRun {
                self.logger.debug("DRY RUN: Would delete \(file.name) - \(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file))")
                let (shouldUpdate, currentProcessed, currentTotalFreed) = await tracker.recordDeleted(size: file.size)
                let overallProcessed = baseProcessedCount + currentProcessed
                let overallFreed = baseFreedSpace + currentTotalFreed
                let overallPercentage = categorySize > 0 ? min(Double(overallFreed) / Double(categorySize) * 100.0, 99.0) : (pathTotal > 0 ? min(Double(overallProcessed) / Double(pathTotal) * 100.0, 99.0) : 0.0)
                
                if shouldUpdate || file.size > 20_000_000 {
                    await progressHandler(CleanupProgress(
                        categoryId: categoryId,
                        categoryName: categoryName,
                        currentFile: file.name,
                        processedFiles: overallProcessed,
                        totalFiles: pathTotal,
                        freedSpace: overallFreed,
                        percentage: overallPercentage
                    ))
                }
                return
            }
            
            do {
                guard FileManager.default.fileExists(atPath: file.path) else {
                    self.logger.debug("File no longer exists: \(file.path)")
                    return
                }
                
                let deletedSize = try await self.fileOperations.deleteFile(at: file.path)
                let (shouldUpdate, currentProcessed, currentTotalFreed) = await tracker.recordDeleted(size: deletedSize)
                let overallProcessed = baseProcessedCount + currentProcessed
                let overallFreed = baseFreedSpace + currentTotalFreed
                let overallPercentage = categorySize > 0 ? min(Double(overallFreed) / Double(categorySize) * 100.0, 99.0) : (pathTotal > 0 ? min(Double(overallProcessed) / Double(pathTotal) * 100.0, 99.0) : 0.0)
                
                if shouldUpdate || file.size > 20_000_000 {
                    await progressHandler(CleanupProgress(
                        categoryId: categoryId,
                        categoryName: categoryName,
                        currentFile: file.name,
                        processedFiles: overallProcessed,
                        totalFiles: pathTotal,
                        freedSpace: overallFreed,
                        percentage: overallPercentage
                    ))
                }
                
            } catch CocoaError.fileWriteFileExists, CocoaError.fileNoSuchFile {
                self.logger.debug("File already deleted or moved: \(file.name)")
            } catch {
                let errorMessage = "Failed to delete \(file.name): \(error.localizedDescription)"
                await tracker.addError(errorMessage)
                self.logger.warning("❌ \(errorMessage)")
            }
        }
        
        let stats = await tracker.getStats()
        let finalOverallProcessed = baseProcessedCount + stats.processedFiles
        let finalFreedTotal = baseFreedSpace + stats.freedSpace
        let batchPercentage = categorySize > 0 ? min(Double(finalFreedTotal) / Double(categorySize) * 100.0, 99.0) : (pathTotal > 0 ? min(Double(finalOverallProcessed) / Double(pathTotal) * 100.0, 99.0) : 0.0)
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: categoryName,
            currentFile: "Cleaning files...",
            processedFiles: finalOverallProcessed,
            totalFiles: pathTotal,
            freedSpace: finalFreedTotal,
            percentage: batchPercentage
        ))
        
        logger.info("Cleanup completed - Processed: \(stats.processedFiles), Freed: \(ByteCountFormatter.string(fromByteCount: Int64(stats.freedSpace), countStyle: .file))")
        
        return CleanupResult(
            categoryId: categoryId,
            categoryName: categoryName,
            success: stats.errors.isEmpty && stats.processedFiles > 0,
            freedSpace: stats.freedSpace,
            errors: stats.errors,
            processedFiles: stats.processedFiles,
            skippedFiles: validFiles.count - stats.processedFiles
        )
    }
    
    // MARK: - Private Methods
    
    private func cleanupDirectory(
        at path: String,
        category: CleanupCategory,
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> (processedFiles: Int, freedSpace: UInt64, errors: [String], skippedFiles: Int) {

        var totalProcessed = 0
        var totalFreed: UInt64 = 0
        var totalErrors: [String] = []
        var totalSkipped = 0
        var batchNumber = 0
        let categorySize = category.size

        while true {
            try Task.checkCancellation()

            batchNumber += 1
            logger.info("Scanning batch \(batchNumber) for path: \(URL(fileURLWithPath: path).lastPathComponent)")

            let currentPercentage = categorySize > 0 ? min(Double(totalFreed) / Double(categorySize) * 100.0, 99.0) : (totalProcessed > 0 ? min(Double(totalProcessed) / Double(totalProcessed + 50_000) * 100.0, 99.0) : 0.0)

            await progressHandler(CleanupProgress(
                categoryId: category.id,
                categoryName: category.name,
                currentFile: "Scanning files...",
                processedFiles: totalProcessed,
                totalFiles: totalProcessed + totalSkipped,
                freedSpace: totalFreed,
                percentage: currentPercentage
            ))

            let files = try await scanner.scanFilesInPath(path, categoryId: category.id, options: options)

            
            guard !files.isEmpty else {
                logger.info("No more files found in \(URL(fileURLWithPath: path).lastPathComponent) after \(batchNumber - 1) batch(es)")
                break
            }

            logger.info("Batch \(batchNumber): found \(files.count) files to delete in \(URL(fileURLWithPath: path).lastPathComponent)")

            let result = try await cleanupFiles(
                files,
                categoryId: category.id,
                categoryName: category.name,
                options: options,
                categorySize: category.size,
                baseProcessedCount: totalProcessed,
                baseFreedSpace: totalFreed,
                progressHandler: progressHandler
            )

            totalProcessed += result.processedFiles
            totalFreed     += result.freedSpace
            totalSkipped   += result.skippedFiles
            totalErrors.append(contentsOf: result.errors)

            logger.info("Batch \(batchNumber) completed — deleted: \(result.processedFiles), freed: \(ByteCountFormatter.string(fromByteCount: Int64(result.freedSpace), countStyle: .file)), skipped: \(result.skippedFiles)")

            if result.processedFiles == 0 {
                logger.info("Batch \(batchNumber) deleted 0 files (all remaining are protected or in use). Stopping.")
                break
            }
        }

        return (
            processedFiles: totalProcessed,
            freedSpace:     totalFreed,
            errors:         totalErrors,
            skippedFiles:   totalSkipped
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
        guard !files.isEmpty else { return [] }
        
        return await withTaskGroup(of: CleanupFile?.self) { group in
            let resultCollector = ResultCollector(expectedCount: files.count)
            
            for file in files {
                group.addTask { [weak self] in
                    guard let self = self else { return nil }
                    
                    guard await self.quickFileCheck(file.path) else {
                        return nil
                    }
                    
                    await self.concurrencySemaphore.wait()
                    defer { Task { await self.concurrencySemaphore.signal() } }
                    
                    let verification = await self.fileOperations.verifyFile(
                        file.path,
                        options: options,
                        shouldbeVerifyInUseFile: true
                    )
                    
                    return verification.exists && !verification.shouldSkip ? file : nil
                }
            }
            
            return await resultCollector.collectResults(from: group)
        }
    }

    private actor ResultCollector {
        private var validFiles: [CleanupFile] = []
        private let expectedCount: Int
        
        init(expectedCount: Int) {
            self.expectedCount = expectedCount
            self.validFiles.reserveCapacity(expectedCount)
        }
        
        func collectResults(from group: TaskGroup<CleanupFile?>) async -> [CleanupFile] {
            for await validFile in group {
                if let file = validFile {
                    validFiles.append(file)
                }
            }
            return validFiles
        }
    }

    private func quickFileCheck(_ path: String) async -> Bool {
        return await Task.detached {
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
            return exists && !isDirectory.boolValue
        }.value
    }

}
