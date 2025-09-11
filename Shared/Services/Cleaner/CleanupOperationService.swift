//
//  CleanupOperationService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import Foundation
import OSLog


// MARK: - CleanupOperationService
class CleanupOperationService {
    
    // MARK: - Dependencies
    private let connectionService: XPCConnectionService
    private let dataManager: XPCDataManager
    private let progressPoller: ProgressPollingService
    private let logger = Logger(subsystem: "com.internxt.desktop", category: "CleanupOperation")
    
    // MARK: - Initialization
    init(connectionService: XPCConnectionService, dataManager: XPCDataManager = XPCDataManager()) {
        self.connectionService = connectionService
        self.dataManager = dataManager
        self.progressPoller = ProgressPollingService(
            connectionService: connectionService,
            dataManager: dataManager
        )
    }
    
    // MARK: - Public Interface
    func performCleanup(
        categories: [CleanupCategory],
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        logger.info("Starting cleanup operation for \(categories.count) categories")
        
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        let categoriesData = try dataManager.encode(categories)
        let optionsData = try dataManager.encode(options)
        
        let operationId = try await startCleanupOperation(
            helper: helper,
            categoriesData: categoriesData,
            optionsData: optionsData
        )
        
        logger.info("Started cleanup operation with ID: \(operationId)")
        
        await progressPoller.pollProgress(
            operationId: operationId,
            progressHandler: progressHandler
        )
        
        let results = try await getCleanupResults(helper: helper, operationId: operationId)
        logger.info("Cleanup completed with \(results.count) results")
        
        return results
    }
    
    func performSpecificFilesCleanup(
        cleanupData: CleanupData,
        options: CleanupOptions,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async throws -> [CleanupResult] {
        
        logger.info("Starting specific files cleanup operation")
        
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        let cleanupDataEncoded = try dataManager.encode(cleanupData)
        let optionsData = try dataManager.encode(options)
        
        let operationId = try await startSpecificFilesCleanupOperation(
            helper: helper,
            cleanupData: cleanupDataEncoded,
            optionsData: optionsData
        )
        
        logger.info("Started specific files cleanup with ID: \(operationId)")
        
        await progressPoller.pollProgress(
            operationId: operationId,
            progressHandler: { progress in
                self.logger.debug("Progress Update - Files: \(progress.processedFiles)/\(progress.totalFiles), Freed: \(progress.freedSpace) bytes, %: \(progress.percentage)")
                await progressHandler(progress)
            }
        )
        
        let results = try await getCleanupResults(helper: helper, operationId: operationId)
        logger.info("Specific files cleanup completed with \(results.count) results")
        
        return results
    }
    
    func cancelCurrentOperation() async {
        logger.info("Cancelling current operation...")
        
        guard let helper = connectionService.getHelperProxy() else {
            logger.warning("Helper not available for cancellation")
            return
        }
        
        helper.cancelOperation {
            self.logger.info("Operation cancelled successfully")
        }
    }
    
    // MARK: - Private Methods
    private func startCleanupOperation(
        helper: CleanerHelperXPCProtocol,
        categoriesData: Data,
        optionsData: Data
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            helper.startCleanupWithProgress(
                categoriesData: categoriesData,
                optionsData: optionsData
            ) { operationId, error in
                if let error = error {
                    self.logger.error("Failed to start cleanup operation: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: operationId)
                }
            }
        }
    }
    
    private func startSpecificFilesCleanupOperation(
        helper: CleanerHelperXPCProtocol,
        cleanupData: Data,
        optionsData: Data
    ) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            helper.startCleanupWithSpecificFilesProgress(
                cleanupData: cleanupData,
                optionsData: optionsData
            ) { operationId, error in
                if let error = error {
                    self.logger.error("Failed to start specific files cleanup: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: operationId)
                }
            }
        }
    }
    
    private func getCleanupResults(
        helper: CleanerHelperXPCProtocol,
        operationId: String
    ) async throws -> [CleanupResult] {
        try await withCheckedThrowingContinuation { continuation in
            helper.getCleanupResult(operationId: operationId) { data, error in
                if let error = error {
                    self.logger.error("Failed to get cleanup results: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    self.logger.error("No cleanup results data received")
                    continuation.resume(throwing: CleanerServiceError.invalidData)
                    return
                }
                
                do {
                    let results = try self.dataManager.decode([CleanupResult].self, from: data)
                    self.logger.info("Successfully decoded \(results.count) cleanup results")
                    continuation.resume(returning: results)
                } catch {
                    self.logger.error("Failed to decode cleanup results: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
