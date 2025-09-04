//
// MARK: - Core Protocol Definitions
//

import Foundation
import os.log

actor CleanerHelperTool {
    
    // MARK: - Dependencies
    
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "HelperTool")
    private let fileOperations: FileOperationsProtocol
    private let scanner: FileScanner
    private let cleanupEngine: CleanupEngine
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Configuration
    
    private let maxConcurrentTasks: Int
    private let concurrencySemaphore: AsyncSemaphore
    
    // MARK: - Initialization
    
    init(maxConcurrentTasks: Int? = nil) {
        let maxTasks = maxConcurrentTasks ?? min(ProcessInfo.processInfo.processorCount, 8)
        self.maxConcurrentTasks = maxTasks
        self.concurrencySemaphore = AsyncSemaphore(value: maxTasks)
        
        // Dependency injection
        self.fileOperations = FileOperationsManager()
        self.scanner = FileScanner(fileOperations: self.fileOperations)
        self.cleanupEngine = CleanupEngine(
            fileOperations: self.fileOperations,
            scanner: self.scanner,
            maxConcurrentTasks: maxTasks
        )
    }
    
    
    func getFilesForCategory(_ category: CleanupCategory,
                            options: CleanupOptions = .default) async throws -> [CleanupFile] {
        
        guard !category.paths.isEmpty else {
            logger.warning("Category \(category.name) has no paths to scan")
            return []
        }
        
        return try await withThrowingTaskGroup(of: [CleanupFile].self) { group in
            var allFiles: [CleanupFile] = []
            
            for path in category.paths {
                group.addTask {
                    await self.concurrencySemaphore.wait()
                    defer { Task { await self.concurrencySemaphore.signal() } }
                    
                    do {
                        return try await self.scanner.scanFilesInPath(path, categoryId: category.id, options: options)
                    } catch {
                        self.logger.warning("Failed to get files for path \(path): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            
            for try await files in group {
                allFiles.append(contentsOf: files)
            }
            
            if allFiles.count > 1000 {
                return allFiles.sorted { $0.size > $1.size }
            }
            
            return allFiles
        }
    }
    
    func scanCategories(_ categories: [CleanupCategory],
                       options: CleanupOptions = .default) async throws -> ScanResult {
        let startTime = Date()
        
        let validCategories = categories.filter { !$0.paths.isEmpty }
        
        let scannedCategories = try await withThrowingTaskGroup(of: CleanupCategory?.self) { group in
            var results: [CleanupCategory] = []
            results.reserveCapacity(validCategories.count)
            
            for category in validCategories {
                group.addTask {
                    await self.concurrencySemaphore.wait()
                    defer { Task { await self.concurrencySemaphore.signal() } }
                    
                    return await self.scanCategory(category, options: options)
                }
            }
            
            for try await scannedCategory in group {
                if let category = scannedCategory {
                    results.append(category)
                }
            }
            
            return results
        }
        
        let totalSize = scannedCategories.reduce(0) { $0 + $1.size }
        let scanDuration = Date().timeIntervalSince(startTime)
        let accessiblePaths = scannedCategories.filter(\.canAccess).count
        let inaccessiblePaths = scannedCategories.count - accessiblePaths
        
        return ScanResult(
            categories: scannedCategories,
            totalSize: totalSize,
            scanDuration: scanDuration,
            accessiblePaths: accessiblePaths,
            inaccessiblePaths: inaccessiblePaths
        )
    }

    func cleanupCategoriesWithProgress(
        _ categories: [CleanupCategory],
        options: CleanupOptions = .default,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        currentTask = Task {}
        
        defer {
            currentTask = nil
            Task { await self.clearCaches() }
        }
        
        var results: [CleanupResult] = []
        
        guard !categories.isEmpty else {
            logger.warning("No categories provided for cleanup")
            return results
        }
        
        let selectedCategories = categories.filter(\.isSelected)
        guard !selectedCategories.isEmpty else {
            logger.warning("No categories selected for cleanup")
            return results
        }
        
        results.reserveCapacity(selectedCategories.count)
        logger.info("Cleanup starting for \(selectedCategories.count) selected categories")
        
        for (index, category) in selectedCategories.enumerated() {
            try Task.checkCancellation()
            
            logger.info("Processing category \(index + 1)/\(selectedCategories.count): \(category.name)")
            
            do {
                let result = try await cleanupEngine.cleanupCategory(category,
                                                                   options: options,
                                                                   progressHandler: progressHandler)
                results.append(result)
                logger.info("Completed category: \(category.name), freed: \(ByteCountFormatter.string(fromByteCount: Int64(result.freedSpace), countStyle: .file))")
                
                if index % 3 == 0 {
                    await clearCaches()
                }
                
            } catch {
                if error is CancellationError {
                    logger.info("Cleanup cancelled by user")
                    throw CleanerError.operationCancelled
                }
                
                logger.error("Failed to cleanup category \(category.name): \(error)")
                let errorResult = CleanupResult(
                    categoryId: category.id,
                    categoryName: category.name,
                    success: false,
                    freedSpace: 0,
                    errors: [error.localizedDescription],
                    processedFiles: 0,
                    skippedFiles: 0
                )
                results.append(errorResult)
            }
        }
        
        logger.info("Cleanup completed for all categories. Total results: \(results.count)")
        return results
    }

    func cleanupWithSpecificFilesProgress(
        _ cleanupData: CleanupData,
        options: CleanupOptions = .default,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        var results: [CleanupResult] = []
        
        switch cleanupData.type {
        case .categoriesOnly(let categories):
            let categoriesWithSelection = categories.map { category in
                var updatedCategory = category
                updatedCategory.isSelected = true
                return updatedCategory
            }
            results = try await cleanupCategoriesWithProgress(categoriesWithSelection,
                                                            options: options,
                                                            progressHandler: progressHandler)
            
        case .filesOnly(let filesByCategory):
            results = try await cleanupSpecificFilesWithProgress(filesByCategory,
                                                               options: options,
                                                               progressHandler: progressHandler)
            
        case .hybrid(let categories, let filesByCategory):
            let categoriesWithSelection = categories.map { category in
                var updatedCategory = category
                updatedCategory.isSelected = true
                return updatedCategory
            }
            let categoryResults = try await cleanupCategoriesWithProgress(categoriesWithSelection,
                                                                        options: options,
                                                                        progressHandler: progressHandler)
            
            let fileResults = try await cleanupSpecificFilesWithProgress(filesByCategory,
                                                                       options: options,
                                                                       progressHandler: progressHandler)
            
            results = categoryResults + fileResults
        }
        
        return results
    }

    func cancelOperation() {
        currentTask?.cancel()
        currentTask = nil
        Task { await clearCaches() }
        logger.info("Operation cancelled and caches cleared")
    }
    
    // MARK: - Private Methods
    
    private func scanCategory(_ category: CleanupCategory,
                             options: CleanupOptions) async -> CleanupCategory? {
        var scannedCategory = category
        
        do {
            let hasAccess = await checkPathsAccess(category.paths)
            scannedCategory.canAccess = hasAccess
            
            if hasAccess {
                let size = try await scanner.calculateDirectorySize(paths: category.paths, options: options)
                scannedCategory.size = size
            } else {
                scannedCategory.size = 0
                scannedCategory.errorMessage = "Permission denied"
                return scannedCategory
            }
            
        } catch {
            scannedCategory.canAccess = false
            scannedCategory.errorMessage = error.localizedDescription
            scannedCategory.size = 0
            logger.warning("Failed to scan category \(category.name): \(error.localizedDescription)")
        }
        
        return scannedCategory
    }
    
    private func checkPathsAccess(_ paths: [String]) async -> Bool {
        for path in paths {
            let hasAccess = FileManager.default.isReadableFile(atPath: path) &&
                          FileManager.default.isDeletableFile(atPath: path)
            if hasAccess { return true }
        }
        return false
    }
    
    private func cleanupSpecificFilesWithProgress(
        _ filesByCategory: [String: [CleanupFile]],
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        var results: [CleanupResult] = []
        results.reserveCapacity(filesByCategory.count)
        
        for (categoryId, files) in filesByCategory {
            try Task.checkCancellation()
            
            do {
                let result = try await cleanupEngine.cleanupFiles(files,
                                                                categoryId: categoryId,
                                                                categoryName: "Specific Files",
                                                                options: options,
                                                                progressHandler: progressHandler)
                results.append(result)
            } catch {
                if error is CancellationError {
                    throw CleanerError.operationCancelled
                }
                
                let errorResult = CleanupResult(
                    categoryId: categoryId,
                    categoryName: "Specific Files",
                    success: false,
                    freedSpace: 0,
                    errors: [error.localizedDescription],
                    processedFiles: 0,
                    skippedFiles: files.count
                )
                results.append(errorResult)
                logger.error("Failed to cleanup files for category \(categoryId): \(error)")
            }
        }
        
        return results
    }
    
    private func clearCaches() async {
        await scanner.clearCache()
        if let fileOpsManager = fileOperations as? FileOperationsManager {
            await fileOpsManager.clearCache()
        }
    }
}

//
// MARK: - Extensions
//

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}



// MARK: - Progress Tracking Protocol

protocol ProgressTrackable: Actor {
    func increment() -> (shouldUpdate: Bool, percentage: Double, processed: Int)
    func getCurrentStats() -> (processed: Int, percentage: Double)
}

// MARK: - Cache Protocol

protocol CacheProtocol: Actor {
    associatedtype Key: Hashable
    associatedtype Value
    
    func get(_ key: Key) -> Value?
    func set(_ key: Key, _ value: Value)
    func clear()
}



//
// MARK: - Supporting Types
//

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    init(value: Int) {
        self.value = value
    }
    
    func wait() async {
        if value > 0 {
            value -= 1
            return
        }
        
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
    
    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

actor ProgressTracker: ProgressTrackable {
    private var processed = 0
    private let total: Int
    private let updateFrequency: Int
    
    init(total: Int) {
        self.total = total
        self.updateFrequency = max(1, total / 50)
    }
    
    func increment() -> (shouldUpdate: Bool, percentage: Double, processed: Int) {
        processed += 1
        let shouldUpdate = processed % updateFrequency == 0 || processed == total
        let percentage = total > 0 ? Double(processed) / Double(total) * 100 : 100
        return (shouldUpdate, percentage, processed)
    }
    
    func getCurrentStats() -> (processed: Int, percentage: Double) {
        let percentage = total > 0 ? Double(processed) / Double(total) * 100 : 100
        return (processed, percentage)
    }
}

actor LRUCache<Key: Hashable, Value>: CacheProtocol {
    private var cache: [Key: Value] = [:]
    private var accessOrder: [Key] = []
    private let maxSize: Int
    
    init(maxSize: Int) {
        self.maxSize = maxSize
    }
    
    func get(_ key: Key) -> Value? {
        guard let value = cache[key] else { return nil }
        
        if let index = accessOrder.firstIndex(of: key) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(key)
        
        return value
    }
    
    func set(_ key: Key, _ value: Value) {
        if cache[key] != nil {
            if let index = accessOrder.firstIndex(of: key) {
                accessOrder.remove(at: index)
            }
        } else if cache.count >= maxSize {
            let oldestKey = accessOrder.removeFirst()
            cache.removeValue(forKey: oldestKey)
        }
        
        cache[key] = value
        accessOrder.append(key)
    }
    
    func clear() {
        cache.removeAll()
        accessOrder.removeAll()
    }
}

