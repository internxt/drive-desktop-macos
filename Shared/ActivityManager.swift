//
//  ActivityManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import Foundation

struct ActivityEntry: Codable {
    let name: String
    let date: Date
    let kind: String
    let status: String;
    let error: String?
}

struct ActivityManager {
    private let activityActionsLimit = 50
    let userDefaults = UserDefaults(suiteName: "JR4S3SY396.group.internxt.desktop")
    
    
    func saveActivityEntry(entry: ActivityEntry) {
        // TODO: Add the activity entry checking the limit to the user defaults
    }
    
    func getLatestActivityEntries() -> [ActivityEntry] {
        let latestActivity = userDefaults?.array(forKey: "latest_activity") as? Data
        
        if let latestActivityUnwrapped = latestActivity {
            do {
                let latestActivityEntries = try JSONDecoder().decode([ActivityEntry].self, from: latestActivityUnwrapped)
                
                return latestActivityEntries.sorted(by: { $0.date.compare($1.date) == .orderedDescending })
            } catch {
                return []
            }
            
        } else {
            return []
        }
        
    }
    
}
