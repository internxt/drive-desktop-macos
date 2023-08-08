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
    let logger = Logger(subsystem: "com.internxt", category: "SyncExtension")
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let anchor = NSFileProviderSyncAnchor(NSUUID().uuidString.data(using: .utf8)!)
    private let driveAPI =  APIFactory.Drive
    
    init(enumeratedItemIdentifier: NSFileProviderItemIdentifier) {
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
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
        
        Task {
            do {
                self.logger.info("Fetching folder content: \(self.enumeratedItemIdentifier.rawValue)")
                let folderId = self.enumeratedItemIdentifier == .rootContainer ? "69934033" : self.enumeratedItemIdentifier.rawValue
                let folderContent = try await driveAPI.getFolderContent(folderId: folderId, debug: false)
                
                self.logger.info("Extension folder fetched: \(folderContent.id)")
                
                var items: Array<NSFileProviderItem> = Array()
                
                folderContent.children.forEach {(children) in
                    // TODO: When moving to use case, create time formatting utilities
                    let createdAtDateFormatter = DateFormatter()
                    createdAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    
                    let updatedAtDateFormatter = DateFormatter()
                    updatedAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(children.id)),
                        filename: children.name,
                        parentId: self.enumeratedItemIdentifier,
                        createdAt:createdAtDateFormatter.date(from:children.createdAt)!,
                        updatedAt: updatedAtDateFormatter.date(from:children.updatedAt)!,
                        itemExtension: nil,
                        itemType: .folder
                    )
                    items.append(item)
                }
                
                
                observer.didEnumerate(items)
                
                observer.finishEnumerating(upTo: nil)
            } catch {
                self.logger.error("Got error fetching folder content: \(error)")
                observer.finishEnumeratingWithError(error)
            }
        }
        
        
        
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
        Task {
            do {
                self.logger.info("Updating folder content: \(self.enumeratedItemIdentifier.rawValue)")
                let folderId = self.enumeratedItemIdentifier == .rootContainer ? "69934033" : self.enumeratedItemIdentifier.rawValue
                let folderContent = try await driveAPI.getFolderContent(folderId: folderId, debug: false)
                
                self.logger.info("Extension folder fetched: \(folderContent.id)")
                
                var items: Array<NSFileProviderItem> = Array()
                
                folderContent.children.forEach {(children) in
                    let createdAtDateFormatter = DateFormatter()
                    createdAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    
                    let updatedAtDateFormatter = DateFormatter()
                    updatedAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                    self.logger.info("ParentID is \(String(children.parentId) ?? "NO PARENT")")
                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(children.id)),
                        filename: children.name,
                        parentId: self.enumeratedItemIdentifier,
                        createdAt:createdAtDateFormatter.date(from:children.createdAt)!,
                        updatedAt: updatedAtDateFormatter.date(from:children.updatedAt)!,
                        itemExtension: nil,
                        itemType: .folder
                    )
                    items.append(item)
                }
                
                
                observer.didUpdate(items)
                
            } catch {
                self.logger.error("Got error fetching folder content: \(error)")
                observer.finishEnumeratingWithError(error)
            }
        }
        
        
        observer.finishEnumeratingChanges(upTo: anchor, moreComing: false)
    }
    
    func currentSyncAnchor(completionHandler: @escaping (NSFileProviderSyncAnchor?) -> Void) {
        self.logger.info("Getting anchor")
        completionHandler(anchor)
    }

  
}
