//
//  FileProviderEnumerator.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import os.log
import InternxtSwiftCore


// Build anchor from this format: filesLasUpdatedAtDate;foldersLastUpdatedAtDate
let initialAnchor = "\(dateToAnchor(Date()));\(dateToAnchor(Date()))"
   
class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    let logger = Logger(subsystem: "com.internxt", category: "sync")
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor(initialAnchor.data(using: .utf8)!)
    private let driveAPI =  APIFactory.Drive
    private let user: DriveUser
    init(user: DriveUser, enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.user = user
        super.init()
    }

    func invalidate() {
        // TODO: perform invalidation of server connection if necessary
    }
    
   


    func enumerateItems(for observer: NSFileProviderEnumerationObserver, startingAt page: NSFileProviderPage) {
     
        self.logger.info("🔵 Enumerating items for \(self.enumeratedItemIdentifier.rawValue)")
        
        if self.enumeratedItemIdentifier == .workingSet {
            observer.didEnumerate([])
            
            observer.finishEnumerating(upTo: nil)
            return
        }
        
        // List trash items
        if self.enumeratedItemIdentifier == .trashContainer {
            observer.didEnumerate([])
            observer.finishEnumerating(upTo: nil)
            return
        }
        
        
        let suggestedPageSize: Int = observer.suggestedPageSize ?? 50
        
        return EnumerateFolderItemsUseCase(user:self.user,enumeratedItemIdentifier: self.enumeratedItemIdentifier, for: observer, from: page).run(limit: suggestedPageSize > 50 ? 50 :suggestedPageSize)
    }
    
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        
        self.logger.info("🔵 Enumerating Changes for \(self.enumeratedItemIdentifier.rawValue)")
        return GetRemoteChangesUseCase(observer: observer, anchor: anchor,user: user).run()
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.logger.info("Getting anchor")
        completionHandler(anchor)
    }

  
}
