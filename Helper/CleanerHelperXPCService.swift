//
//  CleanerHelperXPCService.swift
//  Helper
//
//  Created by Patricio Tovar on 28/8/25.
//

import Foundation
import os.log

@objc(CleanerHelperXPCService)
class CleanerHelperXPCService: NSObject, CleanerHelperXPCProtocol {
    
    private let cleanerTool = CleanerHelperTool()
    private let logger = Logger(subsystem: "com.internxt.cleaner", category: "XPCService")
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
    
    // Task management for cancellation
    private var currentTasks: Set<Task<Void, Never>> = []
    private let taskQueue = DispatchQueue(label: "com.internxt.cleaner.tasks", attributes: .concurrent)
    
    // Progress tracking with polling
    private var activeOperations: [String: OperationState] = [:]
    private let operationsLock = NSLock()
    
    // MARK: - Operation State Management
    
    private struct OperationState {
        var currentProgress: CleanupProgress?
        var finalResult: [CleanupResult]?
        var error: Error?
        var isCompleted: Bool = false
    }
    
    // MARK: - XPC Methods
    
    func scanCategories(categoriesData: Data,
                       optionsData: Data?,
                       reply: @escaping (Data?, NSError?) -> Void) {
        let task = Task {
            do {
                let categories = try decoder.decode([CleanupCategory].self, from: categoriesData)
                let options = try decodeOptions(from: optionsData)
                
                logger.info("Starting scan for \(categories.count) categories")
                let result = try await cleanerTool.scanCategories(categories, options: options)
                
                let data = try encoder.encode(result)
                logger.info("Scan completed successfully. Total size: \(result.totalSize) bytes")
                
                await MainActor.run {
                    reply(data, nil)
                }
            } catch {
                await handleError(error, operation: "scanCategories", reply: reply)
            }
        }
        
        addTask(task)
    }
    
    func cleanupCategoriesWithProgress(categoriesData: Data,
                                     optionsData: Data?,
                                     progressReply: @escaping (Data) -> Void,
                                     finalReply: @escaping (Data?, NSError?) -> Void) {
        let task = Task {
            do {
                let categories = try decoder.decode([CleanupCategory].self, from: categoriesData)
                let options = try decodeOptions(from: optionsData)
                
                logger.info("Starting cleanup with progress for \(categories.count) categories")
                
                // Filtrar solo categorías seleccionadas
                let selectedCategories = categories.filter(\.isSelected)
                logger.info("Processing \(selectedCategories.count) selected categories")
                
                if selectedCategories.isEmpty {
                    logger.warning("No categories selected for cleanup")
                    let emptyResults: [CleanupResult] = []
                    let data = try encoder.encode(emptyResults)
                    await MainActor.run {
                        finalReply(data, nil)
                    }
                    return
                }
                
                // Usar la función con progreso del CleanerHelperTool
                let results = try await cleanerTool.cleanupCategoriesWithProgress(
                    selectedCategories,
                    options: options
                ) { progress in
                    do {
                        let progressData = try self.encoder.encode(progress)
                        await MainActor.run {
                            progressReply(progressData)
                        }
                    } catch {
                        self.logger.error("Failed to encode progress: \(error)")
                    }
                }
                
                let data = try encoder.encode(results)
                let totalFreed = results.reduce(0) { $0 + $1.freedSpace }
                logger.info("Cleanup with progress completed. Total freed: \(totalFreed) bytes")
                
                await MainActor.run {
                    finalReply(data, nil)
                }
                
            } catch {
                logger.error("Cleanup with progress failed: \(error)")
                await handleError(error, operation: "cleanupCategoriesWithProgress", reply: finalReply)
            }
        }
        
        addTask(task)
    }
    
    func getFilesForCategory(categoryData: Data,
                            optionsData: Data?,
                            reply: @escaping (Data?, NSError?) -> Void) {
        let task = Task {
            do {
                let category = try decoder.decode(CleanupCategory.self, from: categoryData)
                let options = try decodeOptions(from: optionsData)
                
                logger.info("Getting files for category: \(category.name)")
                let files = try await cleanerTool.getFilesForCategory(category, options: options)
                
                let data = try encoder.encode(files)
                logger.info("Retrieved \(files.count) files for category: \(category.name)")
                
                await MainActor.run {
                    reply(data, nil)
                }
            } catch {
                await handleError(error, operation: "getFilesForCategory", reply: reply)
            }
        }
        
        addTask(task)
    }
    
    func cancelOperation(reply: @escaping () -> Void) {
        let task = Task {
            logger.info("Cancelling current operations")
            
            // Cancel all current tasks
            await withTaskGroup(of: Void.self) { group in
                for task in currentTasks {
                    group.addTask {
                        task.cancel()
                    }
                }
            }
            
            // Clear tasks
            await taskQueue.sync {
                currentTasks.removeAll()
            }
            
            // Cancel operation in cleaner tool
            await cleanerTool.cancelOperation()
            
            logger.info("All operations cancelled")
            
            await MainActor.run {
                reply()
            }
        }
        
        addTask(task)
    }
    func startCleanupWithProgress(categoriesData: Data,
                                optionsData: Data?,
                                reply: @escaping (String, NSError?) -> Void) {
        let operationId = UUID().uuidString
        
        // Crear estado inicial de la operación
        operationsLock.lock()
        activeOperations[operationId] = OperationState()
        operationsLock.unlock()
        
        // Responder inmediatamente con el operationId
        reply(operationId, nil)
        
        // Ejecutar cleanup en paralelo
        let task = Task {
            do {
                let categories = try decoder.decode([CleanupCategory].self, from: categoriesData)
                let options = try decodeOptions(from: optionsData)
                
                logger.info("🚀 Starting cleanup with progress for \(categories.count) categories - Operation: \(operationId)")
                
                let selectedCategories = categories.filter(\.isSelected)
                logger.info("📋 Processing \(selectedCategories.count) selected categories")
                
                if selectedCategories.isEmpty {
                    logger.warning("⚠️ No categories selected for cleanup")
                    let emptyResults: [CleanupResult] = []
                    
                    operationsLock.lock()
                    if var operationState = activeOperations[operationId] {
                        operationState.finalResult = emptyResults
                        operationState.isCompleted = true
                        activeOperations[operationId] = operationState
                    }
                    operationsLock.unlock()
                    
                    return
                }
                
                // Ejecutar cleanup con progreso
                let results = try await cleanerTool.cleanupCategoriesWithProgress(
                    selectedCategories,
                    options: options
                ) { progress in
                    // Actualizar progreso
                    self.operationsLock.lock()
                    if var operationState = self.activeOperations[operationId] {
                        operationState.currentProgress = progress
                        self.activeOperations[operationId] = operationState
                    }
                    self.operationsLock.unlock()
                }
                
                logger.info("✅ Cleanup completed for operation: \(operationId)")
                
                // Enviar progreso final de 100%
                let finalProgress = CleanupProgress(
                    categoryId: selectedCategories.first?.id ?? "",
                    categoryName: "Cleanup Completed",
                    currentFile: "All files processed",
                    processedFiles: results.reduce(0) { $0 + $1.processedFiles },
                    totalFiles: results.reduce(0) { $0 + $1.processedFiles },
                    freedSpace: results.reduce(0) { $0 + $1.freedSpace },
                    percentage: 100.0
                )
                
                // Marcar como completado y guardar resultados
                operationsLock.lock()
                if var operationState = activeOperations[operationId] {
                    operationState.currentProgress = finalProgress
                    operationState.finalResult = results
                    operationState.isCompleted = true
                    activeOperations[operationId] = operationState
                    logger.info("✅ Operation \(operationId) marked as completed with results")
                }
                operationsLock.unlock()
                
                let totalFreed = results.reduce(0) { $0 + $1.freedSpace }
                logger.info("🎉 Cleanup with progress completed. Total freed: \(totalFreed) bytes - Operation: \(operationId)")
                
            } catch {
                logger.error("❌ Cleanup with progress failed: \(error) - Operation: \(operationId)")
                
                operationsLock.lock()
                if var operationState = activeOperations[operationId] {
                    operationState.error = error
                    operationState.isCompleted = true
                    activeOperations[operationId] = operationState
                }
                operationsLock.unlock()
            }
        }
        
        addTask(task)
    }

    
    func getCleanupProgress(operationId: String,
                          reply: @escaping (Data?, NSError?) -> Void) {
        operationsLock.lock()
        let currentProgress = activeOperations[operationId]?.currentProgress
        operationsLock.unlock()
        
        if let progress = currentProgress {
            do {
                let data = try encoder.encode(progress)
                reply(data, nil)
            } catch {
                let nsError = NSError(domain: "com.internxt.cleaner.xpc", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to encode progress: \(error.localizedDescription)"
                ])
                reply(nil, nsError)
            }
        } else {
            reply(nil, nil)
        }
    }
    
    func getCleanupResult(operationId: String,
                        reply: @escaping (Data?, NSError?) -> Void) {
        operationsLock.lock()
        let operationState = activeOperations[operationId]
        operationsLock.unlock()
        
        guard let state = operationState else {
            let nsError = NSError(domain: "com.internxt.cleaner.xpc", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Operation not found: \(operationId)"
            ])
            logger.error("❌ Operation \(operationId) not found in active operations")
            logger.info("📋 Current operations: \(Array(self.activeOperations.keys))")
            reply(nil, nsError)
            return
        }
        
        // Si hay error, devolverlo
        if let error = state.error {
            let nsError = error as NSError
            logger.error("❌ Operation \(operationId) completed with error: \(error)")
            reply(nil, nsError)
            
            // Limpiar operación con error después de 5 segundos
            Task.detached { [weak self] in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self?.operationsLock.lock()
                self?.activeOperations.removeValue(forKey: operationId)
                self?.operationsLock.unlock()
            }
            return
        }
        
        if state.isCompleted, let results = state.finalResult {
            do {
                let data = try encoder.encode(results)
                logger.info("✅ Returning final results for operation \(operationId)")
                reply(data, nil)
                
                // Programar limpieza después de 30 segundos
                Task.detached { [weak self] in
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    self?.operationsLock.lock()
                    self?.activeOperations.removeValue(forKey: operationId)
                    self?.operationsLock.unlock()
                    self?.logger.info("🗑️ Cleaned up operation \(operationId) after 30 seconds")
                }
                
            } catch {
                let nsError = NSError(domain: "com.internxt.cleaner.xpc", code: -1, userInfo: [
                    NSLocalizedDescriptionKey: "Failed to encode results: \(error.localizedDescription)"
                ])
                logger.error("❌ Failed to encode results for operation \(operationId): \(error)")
                reply(nil, nsError)
            }
        } else {
            // La operación aún no está completada
            logger.debug("⏳ Operation \(operationId) not yet completed")
            reply(nil, nil)
        }
    }
    

    
    func startCleanupWithSpecificFilesProgress(cleanupData: Data,
                                             optionsData: Data?,
                                             reply: @escaping (String, NSError?) -> Void) {
        let operationId = UUID().uuidString
        
        operationsLock.lock()
        activeOperations[operationId] = OperationState()
        operationsLock.unlock()
        
        reply(operationId, nil)
        
        let task = Task {
            do {
                let data = try decoder.decode(CleanupData.self, from: cleanupData)
                let options = try decodeOptions(from: optionsData)
                
                logger.info("Starting cleanup with specific files and progress - Operation: \(operationId)")
                
                let results = try await cleanerTool.cleanupWithSpecificFilesProgress(
                    data,
                    options: options
                ) { progress in
                    self.operationsLock.lock()
                    if var operationState = self.activeOperations[operationId] {
                        operationState.currentProgress = progress
                        self.activeOperations[operationId] = operationState
                    }
                    self.operationsLock.unlock()
                }
                
                operationsLock.lock()
                if var operationState = activeOperations[operationId] {
                    operationState.finalResult = results
                    operationState.isCompleted = true
                    activeOperations[operationId] = operationState
                }
                operationsLock.unlock()
                
            } catch {
                operationsLock.lock()
                if var operationState = activeOperations[operationId] {
                    operationState.error = error
                    operationState.isCompleted = true
                    activeOperations[operationId] = operationState
                }
                operationsLock.unlock()
            }
        }
        
        addTask(task)
    }

    
    // MARK: - Private Helper Methods
    
    private func decodeOptions(from data: Data?) throws -> CleanupOptions {
        guard let data = data else { return .default }
        return try decoder.decode(CleanupOptions.self, from: data)
    }
    
    private func addTask(_ task: Task<Void, Never>) {
        taskQueue.async(flags: .barrier) {
            self.currentTasks.insert(task)
            
            // Clean up completed tasks
            self.currentTasks = self.currentTasks.filter { !$0.isCancelled }
        }
    }
    
    private func handleError(
        _ error: Error,
        operation: String,
        reply: @escaping (Data?, NSError?) -> Void
    ) async {
        let errorMessage = "Operation '\(operation)' failed: \(error.localizedDescription)"
        logger.error("\(errorMessage)")
        
        let nsError: NSError
        if let cleanerError = error as? CleanerError {
            nsError = cleanerError.toNSError()
        } else {
            nsError = NSError(
                domain: "com.internxt.cleaner.xpc",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage,
                    NSUnderlyingErrorKey: error
                ]
            )
        }
        
        await MainActor.run {
            reply(nil, nsError)
        }
    }
    
    private func handleSizeCalculationError(
        _ error: Error,
        reply: @escaping (UInt64, NSError?) -> Void
    ) async {
        let errorMessage = "Size calculation failed: \(error.localizedDescription)"
        logger.error("\(errorMessage)")
        
        let nsError: NSError
        if let cleanerError = error as? CleanerError {
            nsError = cleanerError.toNSError()
        } else {
            nsError = NSError(
                domain: "com.internxt.cleaner.xpc",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: errorMessage,
                    NSUnderlyingErrorKey: error
                ]
            )
        }
        
        await MainActor.run {
            reply(0, nsError)
        }
    }
}

// MARK: - NSXPCListenerDelegate

extension CleanerHelperXPCService: NSXPCListenerDelegate {
    
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        // Configure exported interface
        let interface = NSXPCInterface(with: CleanerHelperXPCProtocol.self)
        
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        
        // Set connection handlers
        newConnection.invalidationHandler = { [weak self] in
            self?.logger.info("XPC connection invalidated")
        }
        
        newConnection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC connection interrupted")
        }
        
        newConnection.resume()
        self.logger.info("New XPC connection accepted and resumed")
        return true
    }
}

// MARK: - Error Handling Extension

extension CleanerError {
    func toNSError() -> NSError {
        let domain = "com.internxt.cleaner"
        let userInfo: [String: Any]
        
        switch self {
        case .permissionDenied(let path):
            userInfo = [
                NSLocalizedDescriptionKey: "Permission denied for path: \(path)",
                NSLocalizedFailureReasonErrorKey: "The application doesn't have permission to access this location."
            ]
            return NSError(domain: domain, code: 1001, userInfo: userInfo)
            
        case .operationCancelled:
            userInfo = [
                NSLocalizedDescriptionKey: "Operation was cancelled",
                NSLocalizedFailureReasonErrorKey: "The user cancelled the operation."
            ]
            return NSError(domain: domain, code: 1002, userInfo: userInfo)
            
        case .pathNotFound(let path):
            userInfo = [
                NSLocalizedDescriptionKey: "Path not found: \(path)",
                NSLocalizedFailureReasonErrorKey: "The specified path does not exist."
            ]
            return NSError(domain: domain, code: 1003, userInfo: userInfo)
            
        default:
            userInfo = [
                NSLocalizedDescriptionKey: "An unknown error occurred",
                NSLocalizedFailureReasonErrorKey: "Please try again."
            ]
            return NSError(domain: domain, code: 9999, userInfo: userInfo)
        }
    }
}
