//
//  XPCConnectionService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import Foundation
import OSLog

// MARK: - XPCConnectionService
class XPCConnectionService: ObservableObject {
    
    // MARK: - Configuration
    private enum Constants {
        static let connectionTimeout: TimeInterval = 10.0
        static let helperRegistrationDelay: UInt64 = 1_000_000_000
        static let helperServiceName = "internxt.InternxtDesktop.cleaner.helper"
    }
    
    // MARK: - Published Properties
    @Published var isConnected: Bool = false
    
    // MARK: - Private Properties
    private let connectionManager: XPCConnectionManaging
  //  private let logger = Logger(subsystem: "com.internxt.desktop", category: "XPCConnection")
    private var currentConnection: NSXPCConnection?
    
    // MARK: - Initialization
    init(connectionManager: XPCConnectionManaging? = nil) {
        self.connectionManager = connectionManager ?? XPCCleanerConnectionManager(
            serviceName: Constants.helperServiceName
        )
    }
    
    deinit {
        invalidateConnection()
    }
    
    // MARK: - Public Interface
    func ensureConnection() async throws {
        guard !isConnected else { return }
        try await establishConnection()
    }
    
    func getHelperProxy() -> CleanerHelperXPCProtocol? {
        return currentConnection?.remoteObjectProxy as? CleanerHelperXPCProtocol
    }
    
    func invalidateConnection() {
        currentConnection?.invalidate()
        currentConnection = nil
        connectionManager.invalidateConnection()
        
        Task { @MainActor in
            self.isConnected = false
        }
        
        cleanerLogger.info("XPC Connection invalidated")
    }
    
    // MARK: - Private Methods
    private func establishConnection() async throws {
        cleanerLogger.info("Establishing XPC connection...")
        
        // Create connection
        guard let connection = connectionManager.createConnection() else {
            throw CleanerServiceError.connectionFailed
        }
        
        currentConnection = connection
        
        // Verify connection works
        try await verifyConnection()
        
        await MainActor.run {
            self.isConnected = true
        }
        
        cleanerLogger.info("XPC Connection established successfully")
    }
    
    private func verifyConnection() async throws {
        guard let helper = getHelperProxy() else {
            throw CleanerServiceError.helperNotAvailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            helper.cancelOperation {
                continuation.resume()
            }
        }
    }
}
