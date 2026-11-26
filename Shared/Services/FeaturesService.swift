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
        static let mailEnabled = "FeaturesService.mailEnabled"
        static let vpnEnabled = "FeaturesService.vpnEnabled"
    }
    
    @Published var backupEnabled: Bool = false
    @Published var antivirusEnabled: Bool = false
    @Published var cleanerEnabled: Bool = false
    @Published var mailEnabled: Bool = false
    @Published var vpnEnabled: Bool = false
    @Published var isLoading: Bool = false
   
    
    private init() {
        loadCachedFeatures()
    }
    
    /// Fetches payment info and updates all feature states
    @MainActor
    func fetchFeaturesStatus() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            logger.info("Fetching features status from payment info")
            let paymentInfo = try await APIFactory.Payment.getPaymentInfo()
            let featuresPerService = paymentInfo.featuresPerService
            backupEnabled = featuresPerService.backups ?? false
            antivirusEnabled = featuresPerService.antivirus ?? false
            cleanerEnabled = featuresPerService.cleaner ?? false
            mailEnabled = featuresPerService.mail ?? false
            vpnEnabled = featuresPerService.vpn ?? false
            
            logger.info("""
                Status for user tier features:
                - Backups enabled: \(backupEnabled)
                - Antivirus enabled: \(antivirusEnabled)
                - Cleaner enabled: \(cleanerEnabled)
                - Mail enabled: \(mailEnabled)
                - VPN enabled: \(vpnEnabled)
                """)
            
            persistFeaturesToCache()
            logger.info("Features status updated successfully")
            
        } catch {
            logger.error("Failed to fetch features status: \(error)")
            
            if let apiError = error as? APIClientError, apiError.statusCode == 404 {
                clearCachedFeatures()
                vpnEnabled = false
                logger.info("Payment info not found (404), disabling all features and clearing cache")
            }
        }
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

    var mailState: MailFeatureState {
        return mailEnabled ? .active : .locked
    }
    
    private func loadCachedFeatures() {
        let defaults = UserDefaults.standard
        backupEnabled = defaults.bool(forKey: CacheKeys.backupEnabled)
        antivirusEnabled = defaults.bool(forKey: CacheKeys.antivirusEnabled)
        cleanerEnabled = defaults.bool(forKey: CacheKeys.cleanerEnabled)
        mailEnabled = defaults.bool(forKey: CacheKeys.mailEnabled)
        vpnEnabled = defaults.bool(forKey: CacheKeys.vpnEnabled)
        logger.info("Loaded cached features — backup: \(backupEnabled), antivirus: \(antivirusEnabled), cleaner: \(cleanerEnabled), mail: \(mailEnabled), vpn: \(vpnEnabled)")
    }
    
    private func persistFeaturesToCache() {
        let defaults = UserDefaults.standard
        defaults.set(backupEnabled, forKey: CacheKeys.backupEnabled)
        defaults.set(antivirusEnabled, forKey: CacheKeys.antivirusEnabled)
        defaults.set(cleanerEnabled, forKey: CacheKeys.cleanerEnabled)
        defaults.set(mailEnabled, forKey: CacheKeys.mailEnabled)
        defaults.set(vpnEnabled, forKey: CacheKeys.vpnEnabled)
        logger.info("Persisted feature flags to cache")
    }
    
     func clearCachedFeatures() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: CacheKeys.backupEnabled)
        defaults.removeObject(forKey: CacheKeys.antivirusEnabled)
        defaults.removeObject(forKey: CacheKeys.cleanerEnabled)
        defaults.removeObject(forKey: CacheKeys.mailEnabled)
        defaults.removeObject(forKey: CacheKeys.vpnEnabled)
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

enum MailFeatureState: Equatable {
    case locked
    case active
}
