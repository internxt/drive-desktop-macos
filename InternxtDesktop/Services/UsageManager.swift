//
//  UsageManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/9/23.
//

import Foundation


class UsageManager: ObservableObject {
    static let shared = UsageManager()
    @Published var loadingUsage: Bool = true
    @Published var usageError: Error? = nil
    // Just to avoid accidentally dividing by 0
    @Published var limit: Int64 = 1
    @Published var driveUsage: Int64 = 0
    @Published var backupsUsage: Int64 = 0
    
    public func getUsedPercentage() -> String {
        let totalUsed = driveUsage + backupsUsage
        let percentage = (totalUsed * 100) / limit
        
        return "\(percentage)%"
        
    }
    
    public func updateUsage() async {
        do {
            DispatchQueue.main.sync {
                self.loadingUsage = true
            }
            let limit = try await APIFactory.Drive.getLimit()
            
            let driveUsage = try await APIFactory.Drive.getUsage()
            
            DispatchQueue.main.async{
                self.limit = limit.maxSpaceBytes
                self.driveUsage = driveUsage.drive
                self.backupsUsage = driveUsage.backups
                self.loadingUsage = false
            }
            
            
        } catch {
            error.reportToSentry()
            DispatchQueue.main.async {
                self.usageError = error
                self.loadingUsage = false
            }
        }
    }
    
    
    public func getFormattedTotalUsage() -> String {
        let total = driveUsage + backupsUsage
        
        return self.format(bytes: total)
    }
    
    public func format(bytes: Int64) -> String {
        
        guard bytes > 0 else {
            return "0 Bytes"
        }
        
        let bytesDouble = Double(bytes)
        let suffixes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        
        let k: Double = 1024
        let i = floor(log(bytesDouble) / log(k))
        let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = i < 3 ? 0 : 1
            numberFormatter.numberStyle = .decimal
            numberFormatter.decimalSeparator = "."
            let numberString = numberFormatter.string(from: NSNumber(value: bytesDouble / pow(k, i))) ?? "Unknown"
            let suffix = suffixes[Int(i)]
            return "\(numberString) \(suffix)"
    }
    
    public func formatParts(bytes: Int64) -> (String, String) {
        
        guard bytes > 0 else {
            return ("0", "Bytes")
        }
        
        let bytesDouble = Double(bytes)
        let suffixes = ["Bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]
        
        let k: Double = 1024
        let i = floor(log(bytesDouble) / log(k))
        let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = i < 3 ? 0 : 1
            numberFormatter.numberStyle = .decimal
            numberFormatter.decimalSeparator = "."
            let numberString = numberFormatter.string(from: NSNumber(value: bytesDouble / pow(k, i))) ?? "Unknown"
            let suffix = suffixes[Int(i)]
            return (numberString, suffix)
    }
}
