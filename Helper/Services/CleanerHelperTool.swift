//
//  CleanerHelperTool.swift
//  Helper
//
//  Created by Patricio Tovar on 28/8/25.
//

import Foundation
import os.log

actor CleanerHelperTool {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "HelperTool")
    private let fileManager = FileManager.default
    private var currentTask: Task<Void, Never>?
    
    // MARK: - Public Methods
    
    func getFilesForCategory(_ category: CleanupCategory,
                            options: CleanupOptions = .default) async throws -> [CleanupFile] {
        var allFiles: [CleanupFile] = []
        allFiles.reserveCapacity(category.paths.count * 100)
        
        await withTaskGroup(of: [CleanupFile].self) { group in
            for path in category.paths {
                guard fileManager.fileExists(atPath: path) else { continue }
                
                group.addTask {
                    do {
                        return try await self.getFilesInPath(path, categoryId: category.id, options: options)
                    } catch {
                        self.logger.warning("Failed to get files for path \(path): \(error.localizedDescription)")
                        return []
                    }
                }
            }
            
            for await files in group {
                allFiles.append(contentsOf: files)
            }
        }
        
        return allFiles.sorted { $0.size > $1.size }
    }
    
    func scanCategories(_ categories: [CleanupCategory],
                       options: CleanupOptions = .default) async throws -> ScanResult {
        let startTime = Date()
        
        let scannedCategories = await withTaskGroup(of: CleanupCategory.self) { group in
            var results: [CleanupCategory] = []
            results.reserveCapacity(categories.count)
            
            for category in categories {
                group.addTask {
                    await self.scanCategory(category, options: options)
                }
            }
            
            for await scannedCategory in group {
                results.append(scannedCategory)
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
        
        currentTask = Task {
            // Task tracking for cancellation
        }
        
        var results: [CleanupResult] = []
        results.reserveCapacity(categories.count)
        
        // Agregar validación inicial
        guard !categories.isEmpty else {
            logger.warning("No categories provided for cleanup")
            return results
        }
        
        // Filtrar solo categorías seleccionadas
        let selectedCategories = categories.filter(\.isSelected)
        logger.info("Cleanup starting for \(selectedCategories.count) selected categories out of \(categories.count) total")
        
        for (index, category) in selectedCategories.enumerated() {
            guard !Task.isCancelled else {
                logger.info("Cleanup cancelled by user")
                throw CleanerError.operationCancelled
            }
            
            logger.info("Processing category \(index + 1)/\(selectedCategories.count): \(category.name)")
            
            do {
                let result = await cleanupCategoryWithProgress(category,
                                                             options: options,
                                                             progressHandler: progressHandler)
                results.append(result)
                logger.info("Completed category: \(category.name), freed: \(result.freedSpace) bytes")
            } catch {
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
            results = try await cleanupCategoriesWithProgress(categoriesWithSelection, options: options, progressHandler: progressHandler)
            
        case .filesOnly(let filesByCategory):
            results = try await cleanupSpecificFilesWithProgress(filesByCategory, options: options, progressHandler: progressHandler)
            
        case .hybrid(let categories, let filesByCategory):
            // Procesar categorías completas primero
            let categoriesWithSelection = categories.map { category in
                var updatedCategory = category
                updatedCategory.isSelected = true
                return updatedCategory
            }
            let categoryResults = try await cleanupCategoriesWithProgress(categoriesWithSelection, options: options, progressHandler: progressHandler)
            
            // Procesar archivos específicos después
            let fileResults = try await cleanupSpecificFilesWithProgress(filesByCategory, options: options, progressHandler: progressHandler)
            
            results = categoryResults + fileResults
        }
        
        return results
    }



    private func cleanupSpecificFilesWithProgress(
        _ filesByCategory: [String: [CleanupFile]],
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        var results: [CleanupResult] = []
        
        for (categoryId, files) in filesByCategory {
            let result = await cleanupFileListWithProgress(files, categoryId: categoryId, options: options, progressHandler: progressHandler)
            results.append(result)
        }
        
        return results
    }



    
    
    private func cleanupFileListWithProgress(
        _ files: [CleanupFile],
        categoryId: String,
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async -> CleanupResult {
        var errors: [String] = []
        var processedFiles = 0
        var freedSpace: UInt64 = 0
        
        logger.info("Starting cleanup for \(files.count) specific files")
        
        // Progreso inicial
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: "Specific Files",
            currentFile: "Starting cleanup...",
            processedFiles: 0,
            totalFiles: files.count,
            freedSpace: 0,
            percentage: 0.0
        ))
        
        for (index, file) in files.enumerated() {
            guard !Task.isCancelled else { break }
            
            // Reportar progreso ANTES de procesar
            await progressHandler(CleanupProgress(
                categoryId: categoryId,
                categoryName: "Specific Files",
                currentFile: "Processing: \(file.name)",
                processedFiles: processedFiles,
                totalFiles: files.count,
                freedSpace: freedSpace,
                percentage: Double(index) / Double(files.count) * 100
            ))
            
            if options.dryRun {
                logger.info("DRY RUN: Would delete \(file.path) - Size: \(file.size)")
                processedFiles += 1
                freedSpace += file.size // IMPORTANTE: También actualizar en dry run
                
                // Reportar progreso después del dry run
                await progressHandler(CleanupProgress(
                    categoryId: categoryId,
                    categoryName: "Specific Files",
                    currentFile: "DRY RUN: \(file.name)",
                    processedFiles: processedFiles,
                    totalFiles: files.count,
                    freedSpace: freedSpace,
                    percentage: Double(processedFiles) / Double(files.count) * 100
                ))
                
                continue
            }
            
            do {
                // Log ANTES de eliminar
                logger.info("Deleting file: \(file.path) - Size: \(file.size) bytes")
                
                // ELIMINAR archivo
                try fileManager.removeItem(atPath: file.path)
                
                // ACTUALIZAR contadores DESPUÉS de eliminar exitosamente
                freedSpace += file.size
                processedFiles += 1
                
                logger.info("✅ Successfully deleted: \(file.path) - Freed: \(file.size) bytes - Total freed: \(freedSpace)")
                
                // REPORTAR progreso con valores actualizados
                await progressHandler(CleanupProgress(
                    categoryId: categoryId,
                    categoryName: "Specific Files",
                    currentFile: "Deleted: \(file.name) (\(ByteCountFormatter.string(fromByteCount: Int64(file.size), countStyle: .file)))",
                    processedFiles: processedFiles,
                    totalFiles: files.count,
                    freedSpace: freedSpace,
                    percentage: Double(processedFiles) / Double(files.count) * 100
                ))
                
            } catch {
                let errorMessage = "Failed to delete: \(file.path) - \(error.localizedDescription)"
                errors.append(errorMessage)
                logger.error("❌ \(errorMessage)")
                
                await progressHandler(CleanupProgress(
                    categoryId: categoryId,
                    categoryName: "Specific Files",
                    currentFile: "Error: \(file.name)",
                    processedFiles: processedFiles,
                    totalFiles: files.count,
                    freedSpace: freedSpace,
                    percentage: Double(index + 1) / Double(files.count) * 100
                ))
            }
        }
        
        // Progreso final del 100% con valores finales
        logger.info("Cleanup completed - Final stats: processed=\(processedFiles), freed=\(freedSpace) bytes")
        
        await progressHandler(CleanupProgress(
            categoryId: categoryId,
            categoryName: "Specific Files",
            currentFile: "Cleanup completed",
            processedFiles: processedFiles,
            totalFiles: files.count,
            freedSpace: freedSpace,
            percentage: 100.0
        ))
        
        return CleanupResult(
            categoryId: categoryId,
            categoryName: "Specific Files",
            success: errors.isEmpty && processedFiles > 0,
            freedSpace: freedSpace,
            errors: errors,
            processedFiles: processedFiles,
            skippedFiles: files.count - processedFiles
        )
    }

        
    func cancelOperation() {
        currentTask?.cancel()
        logger.info("Operation cancelled")
    }
    
    // MARK: - Private Methods
    
    private func getFilesInPath(_ path: String,
                               categoryId: String,
                               options: CleanupOptions) async throws -> [CleanupFile] {
        return try await Task.detached(priority: .utility) { [fileManager, logger] in
            var files: [CleanupFile] = []
            files.reserveCapacity(1000)
            
            let url = URL(fileURLWithPath: path)
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .fileSizeKey,
                .fileAllocatedSizeKey,
                .nameKey,
                .isHiddenKey,
                .contentModificationDateKey,
                .creationDateKey
            ]
            
            var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if options.skipHiddenFiles {
                enumeratorOptions.insert(.skipsHiddenFiles)
            }
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: enumeratorOptions,
                errorHandler: { _, error in
                    logger.debug("Enumerator error: \(error.localizedDescription)")
                    return true
                }
            ) else {
                return files
            }
            
            var processedCount = 0
            let batchSize = 100
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Check cancellation every batch
                if processedCount % batchSize == 0 && Task.isCancelled {
                    break
                }
                
                // Apply depth limit early with skipDescendants optimization
                if let maxDepth = options.maxDepth {
                    let pathComponents = fileURL.pathComponents.count - url.pathComponents.count
                    if pathComponents > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                
                // Apply exclusion rules early
                if await shouldExcludeFileStatic(fileURL.path, options: options) {
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    
                    let file = CleanupFile(
                        id: UUID().uuidString,
                        categoryId: categoryId,
                        name: resourceValues.name ?? fileURL.lastPathComponent,
                        path: fileURL.path,
                        size: UInt64(resourceValues.fileAllocatedSize ?? resourceValues.fileSize ?? 0),
                        isDirectory: resourceValues.isDirectory ?? false,
                        canDelete: fileManager.isDeletableFile(atPath: fileURL.path)
                    )
                    
                    files.append(file)
                    processedCount += 1
                } catch {
                    // Skip files we can't read
                    continue
                }
            }
            
            return files
        }.value
    }
    
    private func scanCategory(_ category: CleanupCategory,
                             options: CleanupOptions) async -> CleanupCategory {
        var scannedCategory = category
        
        do {
            let size = try await calculateDirectorySize(paths: category.paths, options: options)
            scannedCategory.size = size
            scannedCategory.canAccess = await checkPathsAccess(category.paths)
            
        } catch {
            scannedCategory.canAccess = false
            scannedCategory.errorMessage = error.localizedDescription
            logger.warning("Failed to scan category \(category.name): \(error.localizedDescription)")
        }
        
        return scannedCategory
    }
    
    private func calculateDirectorySize(paths: [String],
                                       options: CleanupOptions) async throws -> UInt64 {
        return await withTaskGroup(of: UInt64.self) { group in
            var totalSize: UInt64 = 0
            
            for path in paths {
                group.addTask {
                    do {
                        let (size, _) = try await self.calculatePathDetails(at: path, options: options)
                        return size
                    } catch {
                         self.logger.warning("Failed to calculate size for \(path): \(error.localizedDescription)")
                        return 0
                    }
                }
            }
            
            for await size in group {
                totalSize += size
            }
            
            return totalSize
        }
    }
    
    private func calculatePathDetails(at path: String,
                                     options: CleanupOptions) async throws -> (size: UInt64, fileCount: Int) {
        guard fileManager.fileExists(atPath: path) else {
            return (0, 0)
        }
        
        return await Task.detached(priority: .utility) { [fileManager, logger] in
            var totalSize: UInt64 = 0
            var fileCount: Int = 0
            let url = URL(fileURLWithPath: path)
            
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .fileSizeKey,
                .fileAllocatedSizeKey,
                .isHiddenKey
            ]
            
            var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [.skipsPackageDescendants]
            if options.skipHiddenFiles {
                enumeratorOptions.insert(.skipsHiddenFiles)
            }
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: enumeratorOptions,
                errorHandler: { _, error in
                    logger.debug("Enumerator error: \(error.localizedDescription)")
                    return true
                }
            ) else {
                return (0, 0)
            }
            
            var processedCount = 0
            let batchSize = 50
            
            while let fileURL = enumerator.nextObject() as? URL {
                // Check cancellation every batch
                if processedCount % batchSize == 0 && Task.isCancelled {
                    break
                }
                
                // Apply depth limit early with skipDescendants optimization
                if let maxDepth = options.maxDepth {
                    let pathComponents = fileURL.pathComponents.count - url.pathComponents.count
                    if pathComponents > maxDepth {
                        enumerator.skipDescendants()
                        continue
                    }
                }
                
                // Apply exclusion rules early
                if await shouldExcludeFileStatic(fileURL.path, options: options) {
                    continue
                }
                
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: resourceKeys)
                    
                    if !(resourceValues.isDirectory ?? false) {
                        let fileSize = resourceValues.fileAllocatedSize ?? resourceValues.fileSize ?? 0
                        totalSize += UInt64(fileSize)
                        fileCount += 1
                    }
                    processedCount += 1
                } catch {
                    // Skip files we can't read
                    continue
                }
            }
            
            return (totalSize, fileCount)
        }.value
    }
    
    private func checkPathsAccess(_ paths: [String]) async -> Bool {
        return await withTaskGroup(of: Bool.self) { group in
            for path in paths {
                group.addTask { [fileManager] in
                    return fileManager.isReadableFile(atPath: path) &&
                           fileManager.isDeletableFile(atPath: path)
                }
            }
            
            for await hasAccess in group {
                if hasAccess { return true }
            }
            
            return false
        }
    }
    
    private func checkPathAccess(_ path: String) async -> Bool {
        return fileManager.isReadableFile(atPath: path) &&
               fileManager.isDeletableFile(atPath: path)
    }
    
    private func cleanupCategory(_ category: CleanupCategory,
                                options: CleanupOptions) async -> CleanupResult {
        await cleanupCategoryWithProgress(category, options: options) { _ in }
    }
    
    private func cleanupCategoryWithProgress(
        _ category: CleanupCategory,
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async -> CleanupResult {
        
        var errors: [String] = []
        var processedFiles = 0
        var skippedFiles = 0
        var freedSpace: UInt64 = 0
        
        logger.info("Starting cleanup for category: \(category.name)")
        
        await progressHandler(CleanupProgress(
            categoryId: category.id,
            categoryName: category.name,
            currentFile: "Starting cleanup...",
            processedFiles: 0,
            totalFiles: 0,
            freedSpace: 0,
            percentage: 0.0
        ))
        
        for (pathIndex, path) in category.paths.enumerated() {
            guard !Task.isCancelled else { break }
            guard fileManager.fileExists(atPath: path) else { continue }
            
            logger.info("Processing path \(pathIndex + 1)/\(category.paths.count): \(path)")
            
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
                
                // Enviar progreso después de cada path
                let pathProgress = Double(pathIndex + 1) / Double(category.paths.count) * 100
                await progressHandler(CleanupProgress(
                    categoryId: category.id,
                    categoryName: category.name,
                    currentFile: "Completed path: \(URL(fileURLWithPath: path).lastPathComponent)",
                    processedFiles: processedFiles,
                    totalFiles: processedFiles + skippedFiles,
                    freedSpace: freedSpace,
                    percentage: pathProgress
                ))
                
                logger.info("Path completed. Progress: \(pathProgress)%")
                
            } catch {
                let errorMessage = "Failed to cleanup path: \(path) - \(error.localizedDescription)"
                errors.append(errorMessage)
                logger.error("\(errorMessage)")
            }
        }
        
        // Enviar progreso final
        await progressHandler(CleanupProgress(
            categoryId: category.id,
            categoryName: category.name,
            currentFile: "Cleanup completed",
            processedFiles: processedFiles,
            totalFiles: processedFiles + skippedFiles,
            freedSpace: freedSpace,
            percentage: 100.0
        ))
        
        let success = errors.isEmpty && processedFiles > 0
        
        logger.info("Category cleanup completed. Success: \(success), Files: \(processedFiles), Freed: \(freedSpace)")
        
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
    
    private func cleanupDirectory(
        at path: String,
        category: CleanupCategory,
        options: CleanupOptions,
        currentProcessed: Int,
        currentFreed: UInt64,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> (processedFiles: Int, freedSpace: UInt64, errors: [String], skippedFiles: Int) {
        
        return try await Task.detached(priority: .utility) { [fileManager, logger] in
            let url = URL(fileURLWithPath: path)
            var processedFiles = 0
            var skippedFiles = 0
            var freedSpace: UInt64 = 0
            var errors: [String] = []
            
            let resourceKeys: Set<URLResourceKey> = [
                .isDirectoryKey,
                .fileSizeKey,
                .fileAllocatedSizeKey,
                .nameKey,
                .isHiddenKey
            ]
            
            var enumeratorOptions: FileManager.DirectoryEnumerationOptions = [.skipsSubdirectoryDescendants]
            if options.skipHiddenFiles {
                enumeratorOptions.insert(.skipsHiddenFiles)
            }
            
            guard let enumerator = fileManager.enumerator(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: enumeratorOptions,
                errorHandler: { _, error in
                    errors.append("Enumeration error: \(error.localizedDescription)")
                    return true
                }
            ) else {
                throw CleanerError.permissionDenied(path: path)
            }
            
            var itemsToProcess: [(url: URL, size: UInt64, name: String)] = []
            itemsToProcess.reserveCapacity(100)
            
            // Collect items to process
            while let itemURL = enumerator.nextObject() as? URL {
                guard !Task.isCancelled else { break }
                
                if await shouldExcludeFileStatic(itemURL.path, options: options) {
                    skippedFiles += 1
                    logger.info("Skipping excluded file: \(itemURL.path)")
                    continue
                }
                
                do {
                    let resourceValues = try itemURL.resourceValues(forKeys: resourceKeys)
                    let fileName = resourceValues.name ?? itemURL.lastPathComponent
                    let itemSize = UInt64(resourceValues.fileAllocatedSize ?? resourceValues.fileSize ?? 0)
                    
                    itemsToProcess.append((url: itemURL, size: itemSize, name: fileName))
                } catch {
                    errors.append("Failed to get info for: \(itemURL.path)")
                }
            }
            
            logger.info("Found \(itemsToProcess.count) items to process in \(path)")
            
            // Process items with detailed progress reporting
            for (index, item) in itemsToProcess.enumerated() {
                guard !Task.isCancelled else { break }
                
                let percentage = itemsToProcess.isEmpty ? 0 : Double(index) / Double(itemsToProcess.count) * 100
                
                // Reportar progreso ANTES de procesar cada archivo
                await progressHandler(CleanupProgress(
                    categoryId: category.id,
                    categoryName: category.name,
                    currentFile: item.name,
                    processedFiles: currentProcessed + processedFiles,
                    totalFiles: itemsToProcess.count,
                    freedSpace: currentFreed + freedSpace,
                    percentage: percentage
                ))
                
                // Agregar pequeño delay para testing (puedes removerlo en producción)
//                if itemsToProcess.count > 10 {
//                    try await Task.sleep(nanoseconds: 50_000_000) // 0.05 segundos
//                }
                
                if options.dryRun {
                    logger.info("DRY RUN: Would delete \(item.url.path)")
                    processedFiles += 1
                    continue
                }
                
                do {
                    try fileManager.removeItem(at: item.url)
                    freedSpace += item.size
                    processedFiles += 1
                    logger.debug("Deleted: \(item.url.path)")
                    
                    // Reportar progreso después de eliminar archivo importante (>10MB)
                    if item.size > 10_000_000 {
                        let currentPercentage = Double(index + 1) / Double(itemsToProcess.count) * 100
                        await progressHandler(CleanupProgress(
                            categoryId: category.id,
                            categoryName: category.name,
                            currentFile: "Deleted: \(item.name)",
                            processedFiles: currentProcessed + processedFiles,
                            totalFiles: itemsToProcess.count,
                            freedSpace: currentFreed + freedSpace,
                            percentage: currentPercentage
                        ))
                    }
                    
                } catch {
                    let errorMessage = "Failed to delete: \(item.url.path) - \(error.localizedDescription)"
                    errors.append(errorMessage)
                    logger.warning("\(errorMessage)")
                }
            }
            
            return (processedFiles: processedFiles,
                   freedSpace: freedSpace,
                   errors: errors,
                   skippedFiles: skippedFiles)
        }.value
    }

}

private func shouldExcludeFileStatic(_ path: String, options: CleanupOptions) async -> Bool {
    return await Task.detached(priority: .utility) {
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
                testValue = rule.caseSensitive ? path : path.lowercased()
            }
            
            if rule.type == .regex {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: rule.caseSensitive ? [] : [.caseInsensitive])
                    let range = NSRange(location: 0, length: testValue.utf16.count)
                    if regex.firstMatch(in: testValue, options: [], range: range) != nil {
                        return true
                    }
                } catch {
                    if testValue.contains(pattern) {
                        return true
                    }
                }
            } else {
                if testValue.contains(pattern) {
                    return true
                }
            }
        }
        
        return false
    }.value
}
