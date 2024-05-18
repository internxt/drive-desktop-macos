//
//  FileProviderItemActionsManager.swift
//  SyncExtension
//
//  Created by Robert Garcia on 12/9/23.
//

import Foundation
import FileProvider

class FileProviderItemActionsManager{
    static let MakeAvailableOnline = NSFileProviderExtensionActionIdentifier(rawValue: "internxt.InternxtDesktop.sync.Action.AvailableOnlineOnly")
    static let MakeAvailableOffline = NSFileProviderExtensionActionIdentifier(rawValue: "internxt.InternxtDesktop.sync.Action.AvailableOffline")
    static let RefreshContent = NSFileProviderExtensionActionIdentifier(rawValue: "internxt.InternxtDesktop.sync.Action.RefreshContent")
    static let OpenWebBrowser = NSFileProviderExtensionActionIdentifier(rawValue: "internxt.InternxtDesktop.sync.Action.OpenWebBrowser")
    let userDefaults = UserDefaults.standard

        
    func clean() {
        userDefaults.removeObject(forKey: "offlineItems")
    }
    
    private func getOfflineItemsIdentifiers() -> [String] {
        return userDefaults.object(forKey: "offlineItems") as? [String] ?? []
    }
        
    func makeAvailableOffline(identifier: NSFileProviderItemIdentifier) {
        var offlineItemsIdentifiers: [String] = self.getOfflineItemsIdentifiers()
            
        let alreadyOffline = offlineItemsIdentifiers.contains(where: { $0 == identifier.rawValue })
        if(alreadyOffline) {
            return
        }
        offlineItemsIdentifiers.append(identifier.rawValue)
        
        userDefaults.set(offlineItemsIdentifiers, forKey: "offlineItems")
    }
    
    func makeAvailableOnlineOnly(identifier: NSFileProviderItemIdentifier) {
        let offlineItemsIdentifiers: [String] = self.getOfflineItemsIdentifiers()
            
        userDefaults.set(offlineItemsIdentifiers.filter { offlineItem in
            offlineItem != identifier.rawValue
        }, forKey: "offlineItems")
    }
    
    func isAvailableOffline(identifier: NSFileProviderItemIdentifier) -> Bool {
        let offlineItemsIdentifiers: [String] = self.getOfflineItemsIdentifiers()
        
        return offlineItemsIdentifiers.contains(where: {$0 == identifier.rawValue})
    }
}
