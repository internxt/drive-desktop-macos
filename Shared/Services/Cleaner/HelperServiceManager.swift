//
//  HelperServiceManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import Foundation
import ServiceManagement
import OSLog

class HelperServiceManager: ServiceManaging {
    private let helperServiceName: String
    private let plistName: String
    
    init(serviceName: String) {
        self.helperServiceName = serviceName
        self.plistName = serviceName + ".plist"
    }
    
    private var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }
    
    func registerHelper() throws {
        try service.register()
    }
    
    func unregisterHelper() throws {
        try service.unregister()
    }
    
    func getHelperStatus() -> SMAppService.Status {
        return service.status
    }
}

class XPCDataManager {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func encode<T: Codable>(_ object: T) throws -> Data {
        return try encoder.encode(object)
    }
    
    func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        return try decoder.decode(type, from: data)
    }
}




class HelperManagementService: ObservableObject {
    
    // MARK: - Configuration
    private enum Constants {
        static let helperRegistrationDelay: UInt64 = 1_000_000_000
        static let helperServiceName = "internxt.InternxtDesktop.cleaner.helper"
    }
    
    // MARK: - Published Properties
    @Published var status: CleanerService.HelperStatusType = .notRegistered
    
    private let serviceManager: ServiceManaging
    private let logger = Logger(subsystem: "com.internxt.desktop", category: "HelperManagement")
    
    init(serviceManager: ServiceManaging? = nil) {
        self.serviceManager = serviceManager ?? HelperServiceManager(
            serviceName: Constants.helperServiceName
        )
        updateStatus()
    }
    
    
    func updateStatus() {
        let newStatus = CleanerService.HelperStatusType(
            rawValue: serviceManager.getHelperStatus().rawValue
        )
        
        Task { @MainActor in
            self.status = newStatus
        }
        
        logger.info("Helper status updated to")
    }
    
    func tryRegisterHelper() async -> Bool {
        logger.info("Attempting to register helper...")
        
        do {
            try serviceManager.registerHelper()
            try await Task.sleep(nanoseconds: Constants.helperRegistrationDelay)
            
            updateStatus()
            let isSuccessful = status == .enabled || status == .requiresApproval
            
            if isSuccessful {
                logger.info("Helper registration successful, status:")
            } else {
                logger.warning("Helper registration failed, status: ")
            }
            
            return isSuccessful
        } catch {
            logger.error("Failed to register helper: \(error.localizedDescription)")
            return false
        }
    }
    
    func reinstallHelper() async {
        logger.info("Reinstalling helper daemon...")
        
        do {
            try await uninstallHelper()
            try await Task.sleep(nanoseconds: Constants.helperRegistrationDelay * 2)
            
            try serviceManager.registerHelper()
            updateStatus()
            
            logger.info("Helper re-registered successfully with status")
        } catch {
            logger.error("Helper reinstallation failed: \(error.localizedDescription)")
        }
    }
    
    func uninstallHelper() async throws {
        logger.info("Uninstalling helper daemon...")
        
        do {
            try serviceManager.unregisterHelper()
            updateStatus()
            logger.info("Helper unregistered successfully")
        } catch {
            logger.error("Helper unregistration failed: \(error.localizedDescription)")
            throw CleanerServiceError.connectionFailed
        }
    }
    
    func openSystemSettings() {
        logger.info("Opening system settings for login items...")
        SMAppService.openSystemSettingsLoginItems()
    }
}
