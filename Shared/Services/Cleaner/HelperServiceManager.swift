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
    init(serviceManager: ServiceManaging? = nil) {
        self.serviceManager = serviceManager ?? HelperServiceManager(
            serviceName: Constants.helperServiceName
        )
    }
    
    func ensureHelperIsRegistered() async -> Bool {
        cleanerLogger.info("Checking helper status...")
        await updateStatus()
        
        switch status {
        case .enabled:
            cleanerLogger.info("Helper is already enabled and running")
            return true
            
        case .requiresApproval:
            cleanerLogger.warning("Helper requires user approval in System Settings")
            return true
            
        case .notRegistered, .notFound:
            cleanerLogger.info("Helper not registered, attempting registration...")
            return await tryRegisterHelper()
            
        case .unknown(let code):
            cleanerLogger.warning("Unknown helper status: \(code), attempting registration...")
            return await tryRegisterHelper()
        }
    }
    
    func updateStatus() async {
        let newStatus = CleanerService.HelperStatusType(
            rawValue: serviceManager.getHelperStatus().rawValue
        )
        
        await MainActor.run {
            self.status = newStatus
            cleanerLogger.info("Helper status updated to \(newStatus.userMessage)")
        }
    }
    
    func tryRegisterHelper() async -> Bool {
        cleanerLogger.info("Attempting to register helper...")
        
        do {
            try serviceManager.registerHelper()
            try await Task.sleep(nanoseconds: Constants.helperRegistrationDelay)
            
            await updateStatus()
            let isSuccessful = status == .enabled || status == .requiresApproval
            
            if isSuccessful {
                cleanerLogger.info("Helper registration successful, status:")
            } else {
                cleanerLogger.warning("Helper registration failed, status: ")
            }
            
            return isSuccessful
        } catch {
            cleanerLogger.error("Failed to register helper: \(error.localizedDescription)")
            return false
        }
    }
    
    func reinstallHelper() async {
        cleanerLogger.info("Reinstalling helper daemon...")
        
        do {
            try await uninstallHelper()
            cleanerLogger.info("Helper uninstalled successfully")
        } catch {
            cleanerLogger.warning("Helper uninstallation failed (might not exist): \(error.localizedDescription)")
        }
        
        do {
            try await Task.sleep(nanoseconds: Constants.helperRegistrationDelay * 2)
        } catch {
            cleanerLogger.warning("Sleep interrupted: \(error.localizedDescription)")
        }
        
        do {
            try serviceManager.registerHelper()
            await updateStatus()
            cleanerLogger.info("Helper re-registered successfully with status: \(status.userMessage)")
        } catch {
            cleanerLogger.error("Helper registration failed: \(error.localizedDescription)")
        }
    }
    
    func uninstallHelper() async throws {
        cleanerLogger.info("Uninstalling helper daemon...")
        
        do {
            try serviceManager.unregisterHelper()
            await updateStatus()
            cleanerLogger.info("Helper unregistered successfully")
        } catch {
            cleanerLogger.error("Helper unregistration failed: \(error.localizedDescription)")
            throw CleanerServiceError.connectionFailed
        }
    }
    
    func openSystemSettings() {
        cleanerLogger.info("Opening system settings for login items...")
        SMAppService.openSystemSettingsLoginItems()
    }
}
