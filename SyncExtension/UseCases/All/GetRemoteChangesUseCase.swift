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
    private let deletedStatuses: Set<String> = ["REMOVED", "TRASHED", "DELETED"]
    private var updatedFileProviderItems: [FileProviderItem] = []
    private var deletedItemsIdentifiers: [NSFileProviderItemIdentifier] = []
    private var newFilesLastUpdatedAt: Date = Date()
    private var newFoldersLastUpdatedAt: Date = Date()
    private let syncBatchLimit: Int = 500
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
                
                try await self.obtainFolderChanges(lastUpdatedAt: newFoldersLastUpdatedAt)
                try await self.obtainFileChanges(lastUpdatedAt: newFilesLastUpdatedAt)
                            
                observer.didUpdate(updatedFileProviderItems)
                observer.didDeleteItems(withIdentifiers: deletedItemsIdentifiers)
                
                // Build the new anchor
                
                let filesNewAnchorString = dateToAnchor(newFilesLastUpdatedAt)
                let foldersNewAnchorString = dateToAnchor(newFoldersLastUpdatedAt)
                
                let joinedAnchor = "\(filesNewAnchorString);\(foldersNewAnchorString)".data(using: .utf8)
                
                
                observer.finishEnumeratingChanges(
                    upTo: NSFileProviderSyncAnchor(rawValue: joinedAnchor!),
                    moreComing: false
                )
                
                self.logger.info("✅ Changes enumerated correctly from the server")
            } catch {
                error.reportToSentry()
                observer.finishEnumeratingWithError(error)
                self.logger.error(["❌ Failed to enumerate remote changes", error.getErrorDescription()])
            }
            
        }
    }
    
    
    private func obtainFolderChanges(lastUpdatedAt: Date) async throws {
        var cursor: String? = nil
        var isFirstPage = true

        repeat {
            let response: GetFoldersSyncResponse
            do {
                response = try await APIFactory.DriveNew.getFoldersSync(
                    updatedAt: isFirstPage ? lastUpdatedAt : nil,
                    cursor: cursor,
                    limit: syncBatchLimit,
                    debug: true
                )
            } catch let apiError as APIClientError where apiError.statusCode == 400 && cursor != nil {
                self.logger.warning("⚠️ Invalid cursor (400) on folders, restarting from updatedAt")
                cursor = nil
                isFirstPage = true
                continue
            }

            isFirstPage = false
            cursor = response.nextCursor

            for folder in response.folders {
                let folderIdString = String(folder.id)

                guard let updatedAt = Time.dateFromISOString(folder.updatedAt) else {
                    self.logger.error("Cannot create updatedAt date for folder \(folderIdString) with value \(folder.updatedAt)")
                    continue
                }

                if updatedAt > newFoldersLastUpdatedAt {
                    newFoldersLastUpdatedAt = updatedAt
                }

                if DeletedFolderCache.shared.isFolderDeleted(folderIdString) && folder.status == "EXISTS" {
                    self.logger.info("Folder was restored, removing from cache: \(folderIdString)")
                    DeletedFolderCache.shared.removeFolder(folderIdString)
                }

                if let parentId = folder.parentId,
                   DeletedFolderCache.shared.isFolderDeleted(String(parentId)) {
                    self.logger.info("❌ Parent was deleted, deleting child folder: \(folderIdString)")
                    deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: folderIdString))
                    continue
                }

                if deletedStatuses.contains(folder.status) {
                    deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: folderIdString))
                    DeletedFolderCache.shared.markFolderAsDeleted(folderIdString)
                    continue
                }

                if folder.status == "EXISTS" {
                    guard let createdAt = Time.dateFromISOString(folder.createdAt) else {
                        self.logger.error("Cannot create createdAt date for folder \(folderIdString) with value \(folder.createdAt)")
                        continue
                    }

                    let parentIsRoot = folder.parentId == nil || folder.parentId == user.root_folder_id

                    let folderName = FileProviderItem.getFilename(name: folder.plainName ?? folder.name ?? folderIdString, itemExtension: nil)
                    let isPkg = FileProviderItem.isPackage(filename: folderName)
                    let ext = isPkg ? (folderName as NSString).pathExtension : nil
                    let itemType = isPkg ? RemoteItemType.file : RemoteItemType.folder

                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: folderIdString),
                        filename: folderName,
                        parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folder.parentId!.toString()),
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: ext,
                        itemType: itemType
                    )
                    updatedFileProviderItems.append(item)
                }
            }
        } while cursor != nil
    }

    private func obtainFileChanges(lastUpdatedAt: Date) async throws {
        var cursor: String? = nil
        var isFirstPage = true

        repeat {
            let response: GetFilesSyncResponse
            do {
                response = try await APIFactory.DriveNew.getFilesSync(
                    updatedAt: isFirstPage ? lastUpdatedAt : nil,
                    cursor: cursor,
                    limit: syncBatchLimit,
                    debug: true
                )
            } catch let apiError as APIClientError where apiError.statusCode == 400 && cursor != nil {
                
                self.logger.warning("⚠️ Invalid cursor (400) on files, restarting from updatedAt")
                cursor = nil
                isFirstPage = true
                continue
            }

            isFirstPage = false
            cursor = response.nextCursor

            for file in response.files {
                guard let updatedAt = Time.dateFromISOString(file.updatedAt) else {
                    self.logger.error("Cannot create updatedAt date for file \(file.uuid) with value \(file.updatedAt)")
                    continue
                }

                if updatedAt > newFilesLastUpdatedAt {
                    newFilesLastUpdatedAt = updatedAt
                }

                if deletedStatuses.contains(file.status) {
                    deletedItemsIdentifiers.append(NSFileProviderItemIdentifier(rawValue: file.uuid))
                    continue
                }

                if DeletedFolderCache.shared.isFolderDeleted(String(file.folderId)) {
                    self.logger.info("Parent was deleted for file: \(file.plainName ?? file.name ?? file.uuid)")
                    continue
                }

                if file.status == "EXISTS" {
                    guard let createdAt = Time.dateFromISOString(file.createdAt) else {
                        self.logger.error("Cannot create createdAt date for file \(file.uuid) with value \(file.createdAt)")
                        continue
                    }

                    let parentIsRoot = file.folderId == user.root_folder_id

                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: file.uuid),
                        filename: FileProviderItem.getFilename(name: file.plainName ?? file.name ?? file.uuid, itemExtension: file.type),
                        parentId: parentIsRoot ? .rootContainer : NSFileProviderItemIdentifier(rawValue: file.folderId.toString()),
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: file.type,
                        itemType: .file,
                        size: Int(file.size ?? "0") ?? 0
                    )
                    updatedFileProviderItems.append(item)
                }
            }
        } while cursor != nil
    }
}

