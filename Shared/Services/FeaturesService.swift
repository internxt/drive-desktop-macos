//
//  FeaturesService.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 18/9/25.
//

import Foundation
import InternxtSwiftCore
import Combine

class FeaturesService: ObservableObject {
    static let shared = FeaturesService()
    
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "FeaturesService")
    
    private enum CacheKeys {
        static let backupEnabled = "FeaturesService.backupEnabled"
        static let antivirusEnabled = "FeaturesService.antivirusEnabled"
        static let cleanerEnabled = "FeaturesService.cleanerEnabled"
    }
    
    @Published var backupEnabled: Bool = false
    @Published var antivirusEnabled: Bool = false
    @Published var cleanerEnabled: Bool = false
    @Published var isLoading: Bool = false
   
    
    private init() {
        loadCachedFeatures()
    }
    
    /// Fetches payment info and updates all feature states
    @MainActor
    func fetchFeaturesStatus() async {
        isLoading = true
        
        do {
            logger.info("Fetching features status from payment info")
            let paymentInfo = try await APIFactory.Payment.getPaymentInfo()
            
            // Update backup status
            if let backupStatus = paymentInfo.featuresPerService.backups {
                backupEnabled = backupStatus
                logger.info("Backup feature status: \(backupStatus)")
            } else {
                backupEnabled = false
                logger.warning("No backup information found in payment info")
            }
            
            antivirusEnabled = paymentInfo.featuresPerService.antivirus
            logger.info("Antivirus feature status: \(antivirusEnabled)")
            
            // Update cleaner status
            if let cleanerStatus = paymentInfo.featuresPerService.cleaner {
                cleanerEnabled = cleanerStatus
                logger.info("Cleaner feature status: \(cleanerStatus)")
            } else {
                cleanerEnabled = false
                logger.warning("No cleaner information found in payment info")
            }
            
            persistFeaturesToCache()
            logger.info("Features status updated successfully")
            
        } catch {
            logger.error("Failed to fetch features status: \(error)")
            
            if let apiError = error as? APIClientError, apiError.statusCode == 404 {
                clearCachedFeatures()
                logger.info("Payment info not found (404), disabling all features and clearing cache")
            }
        }
        
        isLoading = false
    }
    
    var backupState: BackupState {
        return backupEnabled ? .active : .locked
    }
    
    var antivirusState: ScanState {
        return antivirusEnabled ? .options : .locked
    }
    
    var cleanerState: CleanerFeatureState {
        return cleanerEnabled ? .active : .locked
    }
    
    private func loadCachedFeatures() {
        let defaults = UserDefaults.standard
        backupEnabled = defaults.bool(forKey: CacheKeys.backupEnabled)
        antivirusEnabled = defaults.bool(forKey: CacheKeys.antivirusEnabled)
        cleanerEnabled = defaults.bool(forKey: CacheKeys.cleanerEnabled)
        logger.info("Loaded cached features — backup: \(backupEnabled), antivirus: \(antivirusEnabled), cleaner: \(cleanerEnabled)")
    }
    
    private func persistFeaturesToCache() {
        let defaults = UserDefaults.standard
        defaults.set(backupEnabled, forKey: CacheKeys.backupEnabled)
        defaults.set(antivirusEnabled, forKey: CacheKeys.antivirusEnabled)
        defaults.set(cleanerEnabled, forKey: CacheKeys.cleanerEnabled)
        logger.info("Persisted feature flags to cache")
    }
    
     func clearCachedFeatures() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CacheKeys.backupEnabled)
        defaults.removeObject(forKey: CacheKeys.antivirusEnabled)
        defaults.removeObject(forKey: CacheKeys.cleanerEnabled)
    }
}


enum ScanState: Equatable {
    case locked
    case options
    case scanning
    case results(noThreats: Bool)
}

enum BackupState: Equatable {
    case locked
    case active
}

enum CleanerFeatureState: Equatable {
    case locked
    case active
}
