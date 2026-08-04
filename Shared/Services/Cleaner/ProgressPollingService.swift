//
//  ProgressPollingService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import Foundation
import OSLog

class ProgressPollingService {
    
    // MARK: - Configuration
    private enum Constants {
        static let pollInterval: UInt64 = 500_000_000
        static let completionWaitTime: UInt64 = 2_000_000_000
        static let errorRetryDelay: UInt64 = 1_000_000_000
    }
    
    // MARK: - Dependencies
    private let connectionService: XPCConnectionService
    private let dataManager: XPCDataManager
    //private let logger = Logger(subsystem: "com.internxt.desktop", category: "ProgressPolling")
    
    // MARK: - Initialization
    init(connectionService: XPCConnectionService, dataManager: XPCDataManager) {
        self.connectionService = connectionService
        self.dataManager = dataManager
    }
    
    // MARK: - Public Interface
    func pollProgress(
        operationId: String,
        progressHandler: @escaping @Sendable (CleanupProgress) async -> Void
    ) async {
        var isCompleted = false
        var lastActivityTime = Date()
        let maxInactivityDuration: TimeInterval = 180 
        
        cleanerLogger.info("Starting progress polling for operation: \(operationId)")
        
        while !isCompleted {
            let inactiveTime = Date().timeIntervalSince(lastActivityTime)
            if inactiveTime > maxInactivityDuration {
                cleanerLogger.warning("Operation \(operationId) timed out due to \(maxInactivityDuration)s of inactivity (no scanning or deleting progress)")
                break
            }
            
            do {
                // Check progress
                if let progress = try await fetchProgress(operationId: operationId) {
                    lastActivityTime = Date()
                    
                    await progressHandler(progress)
                    cleanerLogger.debug("Progress: \(progress.percentage)% - \(progress.currentFile)")
                } else {
                    cleanerLogger.debug("No progress data available yet...")
                }
                
                // Check if operation is completed
                if try await hasResults(operationId: operationId) {
                    cleanerLogger.info("Operation \(operationId) completed - results found")
                    isCompleted = true
                    break
                }
                
                try await Task.sleep(nanoseconds: Constants.pollInterval)
                
            } catch {
                cleanerLogger.error("Error during polling: \(error.localizedDescription)")
                
                if error.localizedDescription.contains("not found") {
                    cleanerLogger.info("Operation not found, stopping polling")
                    isCompleted = true
                    break
                }
                
                try? await Task.sleep(nanoseconds: Constants.errorRetryDelay)
            }
        }
        
        cleanerLogger.info("Polling completed for operation: \(operationId)")
    }
    
    // MARK: - Private Methods
    private func fetchProgress(operationId: String) async throws -> CleanupProgress? {
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            helper.getCleanupProgress(operationId: operationId) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }
                
                do {
                    let progress = try self.dataManager.decode(CleanupProgress.self, from: data)
                    continuation.resume(returning: progress)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func hasResults(operationId: String) async throws -> Bool {
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            helper.getCleanupResult(operationId: operationId) { data, error in
                if let error = error {
                    if error.localizedDescription.contains("not found") {
                        continuation.resume(throwing: error)
                        return
                    }
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: data != nil)
            }
        }
    }
}
