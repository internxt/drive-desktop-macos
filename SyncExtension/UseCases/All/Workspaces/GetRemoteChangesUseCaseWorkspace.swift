//
//  GetRemoteChangesUseCaseWorkspace.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 28/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore



class GetRemoteChangesUseCaseWorkspace {
    let logger = syncExtensionWorkspaceLogger
    private let observer: NSFileProviderChangeObserver
    private let anchor: NSFileProviderSyncAnchor
    private let enumeratedChangesLimit: Int = 50
    private var updatedFileProviderItems: [FileProviderItem] = []
    private var deletedItemsIdentifiers: [NSFileProviderItemIdentifier] = []
    private var newFilesLastUpdatedAt: Date = Date()
    private var newFoldersLastUpdatedAt: Date = Date()
    private let workspace: [AvailableWorkspace]
    init(observer: NSFileProviderChangeObserver, anchor: NSFileProviderSyncAnchor,workspace: [AvailableWorkspace]) {
        self.observer = observer
        self.anchor = anchor
        self.workspace = workspace
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
    
    private func obtainFileChanges(lastUpdatedAt: Date, limit: Int, recommendedBatchSize: Int?) async throws -> Void {
        let workspaceId = workspace[0].workspaceUser.workspaceId
        let authManager = AuthManager()
        
        
        guard let workspaceCredentials = authManager.workspaceCredentials else {
            logger.error("Workspace credentials not configured")
            return }

        
        let updatedFiles = try await APIFactory.DriveWorkspace.getUpdatedFilesWorkspace(
            updatedAt: lastUpdatedAt,
            status: "ALL",
            limit: limit,
            offset:0,
            bucketId: workspaceCredentials.bucket,
            workspaceId: workspaceId,
            debug: true
        )
        
        let hasMoreFiles = updatedFiles.count == limit
        
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
                
                if updatedAt > newFilesLastUpdatedAt {
                    newFilesLastUpdatedAt = updatedAt
                }
                
                guard let folderUuid = file.folderUuid else {
                    self.logger.error("Cannot get folder uuid")
                    return
                }
                
                let parentIsRoot = folderUuid == workspace[0].workspaceUser.rootFolderId
                
                let item = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(file.uuid)),
                    filename: FileProviderItem.getFilename(name: file.plainName ?? file.name , itemExtension: file.type) ,
                    parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folderUuid),
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
            _ = try await self.obtainFileChanges(lastUpdatedAt: newFilesLastUpdatedAt, limit: self.enumeratedChangesLimit, recommendedBatchSize: recommendedBatchSize)
        }
    }
    
    
    private func obtainFolderChanges(lastUpdatedAt: Date, limit: Int,recommendedBatchSize: Int?) async throws -> Void {
        let workspaceId = workspace[0].workspaceUser.workspaceId
        
        let updatedFolders = try await APIFactory.DriveWorkspace.getUpdatedFoldersWorkspace(
            updatedAt: lastUpdatedAt,
            status: "ALL",
            limit: self.enumeratedChangesLimit,
            offset:0, 
            workspaceId: workspaceId,
            debug:true
        )
        
        let hasMoreFolders = updatedFolders.count == limit

        updatedFolders.forEach{ (folder) in
            
            guard let folderUuid = folder.uuid else {
                self.logger.error("Cannot get folder uuid")
                return
            }
            
            if folder.status == "REMOVED" || folder.status == "TRASHED" {
                deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: folderUuid))
                return
            }
            
            if folder.status == "EXISTS" {
                guard let createdAt = Time.dateFromISOString(folder.createdAt) else {
                    self.logger.error("Cannot create createdAt date for item \(folderUuid) with value \(folder.createdAt)")
                    return
                }
                
                guard let updatedAt = Time.dateFromISOString(folder.updatedAt) else {
                    self.logger.error("Cannot create updatedAt date for item \(folderUuid) with value \(folder.updatedAt)")
                    return
                }
                
                if updatedAt > lastUpdatedAt {
                    newFoldersLastUpdatedAt = updatedAt
                }
                
             
                guard let folderParentUuid = folder.parentUuid else {
                    self.logger.error("Cannot get folder parent uuid")
                    return
                }
                
                let parentIsRoot = folderParentUuid == workspace[0].workspaceUser.rootFolderId
                
                let item = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: folderUuid),
                    filename: FileProviderItem.getFilename(name: folder.plainName ?? folder.name , itemExtension: nil),
                    parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folderParentUuid),
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
}
