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
    
    @Published var backupEnabled: Bool = false
    @Published var antivirusEnabled: Bool = false
    @Published var cleanerEnabled: Bool = false
    @Published var isLoading: Bool = false
    @Published var lastFetchDate: Date?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
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
            
            lastFetchDate = Date()
            logger.info("Features status updated successfully")
            
        } catch {
            logger.error("Failed to fetch features status: \(error)")
            
            if let apiError = error as? APIClientError {
                if apiError.statusCode == 404 {
                    backupEnabled = false
                    antivirusEnabled = false
                    cleanerEnabled = false
                    logger.info("Payment info not found (404), disabling all features")
                }
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
