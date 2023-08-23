//
//  FileProviderEnumerator.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import os.log
import InternxtSwiftCore
class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    let logger = Logger(subsystem: "com.internxt", category: "sync")
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor(NSUUID().uuidString.data(using: .utf8)!)
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
        /* TODO:
         - inspect the page to determine whether this is an initial or a follow-up request
         
         If this is an enumerator for a directory, the root container or all directories:
         - perform a server request to fetch directory contents
         If this is an enumerator for the active set:
         - perform a server request to update your local database
         - fetch the active set from your local database
         
         - inform the observer about the items returned by the server (possibly multiple times)
         - inform the observer that you are finished with this page
         */
        
        
        logger.info("Item identifier \(self.enumeratedItemIdentifier.rawValue)")
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
        return EnumerateFolderItemsUseCase(user:self.user,enumeratedItemIdentifier: self.enumeratedItemIdentifier, for: observer, from: page).run(limit: suggestedPageSize > 50 ? 50 :suggestedPageSize, offset: 0)
    }
    
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        
        self.logger.info("Enumerating Changes from: \(anchor.rawValue)")
        /* TODO:
         - query the server for updates since the passed-in sync anchor
         
         If this is an enumerator for the active set:
         - note the changes in your local database
         
         - inform the observer about item deletions and updates (modifications + insertions)
         - inform the observer when you have finished enumerating up to a subsequent sync anchor
         */
        // TODO: Move to usecase
        
        
        
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.logger.info("Getting anchor")
        completionHandler(anchor)
    }

  
}
