//
//  FileProviderEnumerator.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import InternxtSwiftCore


// Build anchor from this format: filesLasUpdatedAtDate;foldersLastUpdatedAtDate
let initialAnchor = "\(dateToAnchor(Date()));\(dateToAnchor(Date()))"
   
class FileProviderEnumerator: NSObject, NSFileProviderEnumerator {
    let logger = syncExtensionLogger
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor(initialAnchor.data(using: .utf8)!)
    private let user: DriveUser
    private let domain: NSFileProviderDomain
    private let workspace: [AvailableWorkspace]
    init(user: DriveUser, enumeratedItemIdentifier: NSFileProviderItemIdentifier , domain: NSFileProviderDomain, workspace: [AvailableWorkspace]) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.user = user
        self.domain = domain
        self.workspace = workspace
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
        let isPersonalDrive = domain.identifier.rawValue ==  user.uuid
        
        return isPersonalDrive ? EnumerateFolderItemsUseCase(user:self.user,enumeratedItemIdentifier: self.enumeratedItemIdentifier, for: observer, from: page).run(limit: suggestedPageSize > 50 ? 50 :suggestedPageSize) :
        EnumerateFolderItemsWorkspaceUseCase(user:self.user,enumeratedItemIdentifier: self.enumeratedItemIdentifier, for: observer, from: page, workspace: workspace).run(limit: suggestedPageSize > 50 ? 50 :suggestedPageSize)
        
    }
    
    
    func enumerateChanges(for observer: NSFileProviderChangeObserver, from anchor: NSFileProviderSyncAnchor) {
        let isPersonalDrive = domain.identifier.rawValue ==  user.uuid
        
        return isPersonalDrive ? GetRemoteChangesUseCase(observer: observer, anchor: anchor,user: user).run() :
        GetRemoteChangesUseCaseWorkspace(observer: observer, anchor: anchor,workspace: workspace).run()
 
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        completionHandler(anchor)
    }

  
}
