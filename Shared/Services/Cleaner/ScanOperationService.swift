//
//  ScanOperationService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import Foundation
import OSLog

// MARK: - ScanOperationService
class ScanOperationService {
    
    // MARK: - Dependencies
    private let connectionService: XPCConnectionService
    private let dataManager: XPCDataManager
    private let logger = Logger(subsystem: "com.internxt.desktop", category: "ScanOperation")
    
    // MARK: - Initialization
    init(connectionService: XPCConnectionService, dataManager: XPCDataManager = XPCDataManager()) {
        self.connectionService = connectionService
        self.dataManager = dataManager
    }
    
    // MARK: - Public Interface
    func performScan() async throws -> ScanResult {
        logger.info("Starting scan operation...")
        
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        let categories = CleanerCategories.getAllCategories()
        let options = CleanupOptions.default
        
        let categoriesData = try dataManager.encode(categories)
        let optionsData = try dataManager.encode(options)
        
        return try await withCheckedThrowingContinuation { continuation in
            helper.scanCategories(
                categoriesData: categoriesData,
                optionsData: optionsData
            ) { data, error in
                self.handleScanResponse(data: data, error: error, continuation: continuation)
            }
        }
    }
    
    func getFilesForCategory(
        _ category: CleanupCategory,
        options: CleanupOptions = .default
    ) async throws -> [CleanupFile] {
        logger.info("Loading files for category: \(category.name)")
        
        guard let helper = connectionService.getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        let categoryData = try dataManager.encode(category)
        let optionsData = try dataManager.encode(options)
        
        return try await withCheckedThrowingContinuation { continuation in
            helper.getFilesForCategory(
                categoryData: categoryData,
                optionsData: optionsData
            ) { data, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let data = data else {
                    continuation.resume(throwing: CleanerServiceError.invalidData)
                    return
                }
                
                do {
                    let files = try self.dataManager.decode([CleanupFile].self, from: data)
                    self.logger.info("Loaded \(files.count) files for category: \(category.name)")
                    continuation.resume(returning: files)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    private func handleScanResponse(
        data: Data?,
        error: Error?,
        continuation: CheckedContinuation<ScanResult, Error>
    ) {
        if let error = error {
            logger.error("Scan failed with error: \(error.localizedDescription)")
            continuation.resume(throwing: CleanerServiceError.scanFailed(underlying: error))
            return
        }
        
        guard let data = data else {
            logger.error("Scan failed: no data received")
            continuation.resume(throwing: CleanerServiceError.invalidData)
            return
        }
        
        do {
            let scanResult = try dataManager.decode(ScanResult.self, from: data)
            logger.info("Scan completed successfully with \(scanResult.categories.count) categories")
            continuation.resume(returning: scanResult)
        } catch {
            logger.error("Scan failed during decoding: \(error.localizedDescription)")
            continuation.resume(throwing: CleanerServiceError.scanFailed(underlying: error))
        }
    }
}
