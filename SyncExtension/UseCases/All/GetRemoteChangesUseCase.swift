//
//  GetRemoteChangesUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/9/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log


struct FilesAndFoldersAnchor {
    public let filesAnchorDate: Date
    public let foldersAnchorDate: Date
}
struct GetRemoteChangesUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "GetRemoteChanges")
    private let driveAPI: DriveAPI = APIFactory.Drive
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let observer: NSFileProviderChangeObserver
    private let anchor: NSFileProviderSyncAnchor
    private let user: DriveUser
    private let enumeratedChangesLimit: Int = 50
    
    
    init(observer: NSFileProviderChangeObserver, anchor: NSFileProviderSyncAnchor, user: DriveUser) {
        self.observer = observer
        self.anchor = anchor
        self.user = user
    }
    
    private func getFilesAndFoldersLastUpdate(_ anchor: NSFileProviderSyncAnchor) -> FilesAndFoldersAnchor {
        
        // 1. Anchor to string
        let anchorString = String(data: anchor.rawValue, encoding: .utf8)
        
        // 2. The dates are separated by a ;
        let parts = anchorString?.components(separatedBy: ";")
        
        // 3. First one is the files date, second one is the folders date
        let filesAnchor = parts?.first
        let foldersAnchor = parts?.last
        
        
        let filesLastUpdatedAt = filesAnchor == nil ? Date() : anchorToDate(filesAnchor!)
        let foldersLastUpdatedAt = foldersAnchor == nil ? Date() : anchorToDate(foldersAnchor!)
            
        return FilesAndFoldersAnchor(filesAnchorDate: filesLastUpdatedAt ?? Date(), foldersAnchorDate: foldersLastUpdatedAt ?? Date())
    }
    func run() {
        // Since we need to store the updatedAt for files and folders separated, both dates are stored in the anchor, so we split them
        let lastUpdatedAt = getFilesAndFoldersLastUpdate(anchor)
       
        
       
        Task {
            do {
                var hasMoreFiles = false
                var hasMoreFolders = false
                var newFilesLastUpdatedAt: Date = lastUpdatedAt.filesAnchorDate
                var newFoldersLastUpdatedAt: Date = lastUpdatedAt.foldersAnchorDate
                var deletedItemsIdentifiers: [NSFileProviderItemIdentifier] = []
                var updatedItems: [FileProviderItem] = []
                
                let updatedFiles = try await APIFactory.DriveNew.getUpdatedFiles(
                    updatedAt: lastUpdatedAt.filesAnchorDate,
                    status: "ALL",
                    limit: self.enumeratedChangesLimit,
                    offset:0,
                    debug:false
                )
                
                hasMoreFiles = updatedFiles.count == self.enumeratedChangesLimit
                updatedFiles.forEach{ (file) in
                    
                    if file.status == "REMOVED" || file.status == "TRASHED" {
                        deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: String(file.uuid)))
                    }
                    
                    if file.status == "EXISTS" {
                        guard let createdAt = Time.dateFromISOString(file.createdAt) else {
                            self.logger.error("Cannot create createdAt date for item \(file.id) with value \(file.createdAt)")
                            return
                        }
                        
                        guard let updatedAt = Time.dateFromISOString(file.updatedAt) else {
                            self.logger.error("Cannot create updatedAt date for item \(file.id) with value \(file.updatedAt)")
                            return
                        }
                        
                        if updatedAt > lastUpdatedAt.filesAnchorDate {
                            newFilesLastUpdatedAt = updatedAt
                        }
                        
                        let parentIsRoot = file.folderId == user.root_folder_id

                        let item = FileProviderItem(
                            identifier: NSFileProviderItemIdentifier(rawValue: String(file.uuid)),
                            filename: FileProviderItem.getFilename(name: file.plainName ?? file.name , itemExtension: file.type) ,
                            parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: file.folderId.toString()),
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            itemExtension: file.type,
                            itemType: .file,
                            size: Int(file.size) ?? 0
                        )
                        
                        updatedItems.append(item)
                    }
                }
                
                
                let updatedFolders = try await APIFactory.DriveNew.getUpdatedFolders(
                    updatedAt: lastUpdatedAt.foldersAnchorDate,
                    status: "ALL",
                    limit: self.enumeratedChangesLimit,
                    offset:0,
                    debug:false
                )
                
                hasMoreFolders = updatedFolders.count == self.enumeratedChangesLimit
                updatedFolders.forEach{ (folder) in
                    if folder.status == "REMOVED" || folder.status == "TRASHED" {
                        deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: String(folder.id)))
                        
                    }
                    
                    if folder.status == "EXISTS" {
                        guard let createdAt = Time.dateFromISOString(folder.createdAt) else {
                            self.logger.error("Cannot create createdAt date for item \(folder.id) with value \(folder.createdAt)")
                            return
                        }
                        
                        guard let updatedAt = Time.dateFromISOString(folder.updatedAt) else {
                            self.logger.error("Cannot create updatedAt date for item \(folder.id) with value \(folder.updatedAt)")
                            return
                        }
                        
                        if updatedAt > lastUpdatedAt.filesAnchorDate {
                            newFoldersLastUpdatedAt = updatedAt
                        }
                        
                        let parentIsRoot = folder.parentId == nil || folder.parentId == user.root_folder_id

                        let item = FileProviderItem(
                            identifier: NSFileProviderItemIdentifier(rawValue: String(folder.id)),
                            filename: FileProviderItem.getFilename(name: folder.plainName ?? folder.name , itemExtension: nil),
                            parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folder.parentId!.toString()),
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            itemExtension: nil,
                            itemType: .folder
                        )
                        
                        updatedItems.append(item)
                    }
                }
                
                
                
                
                observer.didUpdate(updatedItems)
                observer.didDeleteItems(withIdentifiers: deletedItemsIdentifiers)
                
                // Build the new anchor
                
                let filesNewAnchorString = dateToAnchor(newFilesLastUpdatedAt)
                let foldersNewAnchorString = dateToAnchor(newFoldersLastUpdatedAt)
                
                let joinedAnchor = "\(filesNewAnchorString);\(foldersNewAnchorString)".data(using: .utf8)
                
                
                observer.finishEnumeratingChanges(
                    upTo: NSFileProviderSyncAnchor(rawValue: joinedAnchor!),
                    moreComing: hasMoreFiles || hasMoreFolders
                )
                
                self.logger.info("✅ Changes enumerated correctly from the server")
            } catch {
                error.reportToSentry()
                observer.finishEnumeratingWithError(error)
                self.logger.error("❌ Failed to enumerate remote changes")
            }
            
        }
    }
}
