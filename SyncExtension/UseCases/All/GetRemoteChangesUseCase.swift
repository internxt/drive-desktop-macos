//
//  GetRemoteChangesUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/9/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore


struct FilesAndFoldersAnchor {
    public let filesAnchorDate: Date
    public let foldersAnchorDate: Date
}
class GetRemoteChangesUseCase {
    let logger = syncExtensionLogger
    private let observer: NSFileProviderChangeObserver
    private let anchor: NSFileProviderSyncAnchor
    private let user: DriveUser
    private let enumeratedChangesLimit: Int = 50
    private var updatedFileProviderItems: [FileProviderItem] = []
    private var deletedItemsIdentifiers: [NSFileProviderItemIdentifier] = []
    private var newFilesLastUpdatedAt: Date = Date()
    private var newFoldersLastUpdatedAt: Date = Date()
    private var fileOffset: Int = 0
    private var folderOffset: Int = 0
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
                newFilesLastUpdatedAt = lastUpdatedAt.filesAnchorDate
                newFoldersLastUpdatedAt = lastUpdatedAt.foldersAnchorDate
                
                try await self.obtainFileChanges(lastUpdatedAt: newFilesLastUpdatedAt, limit: self.enumeratedChangesLimit, recommendedBatchSize: observer.suggestedBatchSize)
                try await self.obtainFolderChanges(lastUpdatedAt: newFoldersLastUpdatedAt, limit: self.enumeratedChangesLimit, recommendedBatchSize: observer.suggestedBatchSize)
                            
                
                observer.didUpdate(updatedFileProviderItems)
                observer.didDeleteItems(withIdentifiers: deletedItemsIdentifiers)
                
                // Build the new anchor
                
                let filesNewAnchorString = dateToAnchor(newFilesLastUpdatedAt)
                let foldersNewAnchorString = dateToAnchor(newFoldersLastUpdatedAt)
                
                let joinedAnchor = "\(filesNewAnchorString);\(foldersNewAnchorString)".data(using: .utf8)
                
                
                observer.finishEnumeratingChanges(
                    upTo: NSFileProviderSyncAnchor(rawValue: joinedAnchor!),
                    
                    moreComing: true
                )
                
                self.logger.info("✅ Changes enumerated correctly from the server")
            } catch {
                error.reportToSentry()
                observer.finishEnumeratingWithError(error)
                self.logger.error(["❌ Failed to enumerate remote changes", error.getErrorDescription()])
            }
            
        }
    }
    
    
    private func obtainFolderChanges(lastUpdatedAt: Date, limit: Int,recommendedBatchSize: Int?) async throws -> Void {
        let updatedFolders = try await APIFactory.DriveNew.getUpdatedFolders(
            updatedAt: lastUpdatedAt,
            status: "ALL",
            limit: self.enumeratedChangesLimit,
            offset:folderOffset,
            debug:true
        )
        folderOffset += limit
        let hasMoreFolders = updatedFolders.count == limit

        var folderDeletionCache: [String: Bool] = [:]

        for folder in updatedFolders {
            let folderId = String(folder.id)
            let parentFolderId = folder.parentId?.toString() ?? ""
            
            if !parentFolderId.isEmpty, folderDeletionCache[parentFolderId] == nil {
                do {
                    let parentFolderMeta = try await APIFactory.DriveNew.getFolderMetaById(id: parentFolderId)
                    folderDeletionCache[parentFolderId] = parentFolderMeta.deleted
                  
                } catch {
                    self.logger.error("❌ Error fetching parent folder metadata for folder \(folder.id): \(error.localizedDescription)")
                    continue
                }
            }
            
            if folderDeletionCache[parentFolderId] == true {
                deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: folderId))
                continue
            }
            if folder.status == "REMOVED" || folder.status == "TRASHED" {
                deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: String(folder.id)))
                folderDeletionCache[folderId] = true
                continue
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
                
                if updatedAt > lastUpdatedAt {
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
                
                updatedFileProviderItems.append(item)
            }
        }
        
        if hasMoreFolders {
            self.logger.info("There are more folders, requesting them...")
            _ = try await self.obtainFolderChanges(lastUpdatedAt: newFilesLastUpdatedAt, limit: self.enumeratedChangesLimit, recommendedBatchSize: recommendedBatchSize)
        }
    }

    
    private func obtainFileChanges(lastUpdatedAt: Date, limit: Int, recommendedBatchSize: Int?) async throws -> Void {
        let updatedFiles = try await APIFactory.DriveNew.getUpdatedFiles(
            updatedAt: lastUpdatedAt,
            status: "ALL",
            limit: limit,
            offset:fileOffset,
            bucketId: user.bucket,
            debug: true
        )
        fileOffset += limit
        let hasMoreFiles = updatedFiles.count == limit
        
        var folderDeletionCache: [String: Bool] = [:]

        for file in updatedFiles {
            let folderId = String(file.folderId)

            if folderDeletionCache[folderId] == nil {
                do {
                    let folderMeta = try await APIFactory.DriveNew.getFolderMetaById(id: folderId)
                    folderDeletionCache[folderId] = folderMeta.deleted
                } catch {
                    self.logger.error("❌ Error fetching folder metadata for file \(file.id): \(error.localizedDescription)")
                    continue
                }
            }

            if folderDeletionCache[folderId] == true {
                deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: String(file.uuid)))
                continue
            }

            if file.status == "REMOVED" || file.status == "TRASHED" {
                deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: String(file.uuid)))
                continue
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
                
                if updatedAt > newFilesLastUpdatedAt {
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
                
                updatedFileProviderItems.append(item)
            }
        }
        
        if hasMoreFiles {
            self.logger.info("There are more files, requesting them...")
            try await self.obtainFileChanges(lastUpdatedAt: newFilesLastUpdatedAt, limit: self.enumeratedChangesLimit, recommendedBatchSize: recommendedBatchSize)
        }
    }
}

