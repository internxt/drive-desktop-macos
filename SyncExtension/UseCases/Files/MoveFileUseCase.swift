//
//  MoveFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import RealmSwift


struct MoveFileUseCase {
    let logger = syncExtensionLogger
    let driveNewAPI = APIFactory.DriveNew
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    private let activityManager: ActivityManager

    init(
        user: DriveUser,
        item: NSFileProviderItem,
        changedFields: NSFileProviderItemFields,
        activityManager: ActivityManager,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
        self.activityManager = activityManager
    }
    
    
    func run() -> Progress {
        let trackingId = ObjectId.generate()
        Task {
            self.logger.info("Moving file '\(item.filename)' with uuid \(item.itemIdentifier.rawValue) to \(item.parentItemIdentifier.rawValue)")
            activityManager.saveActivityEntry(entry: ActivityEntry(_id: trackingId, filename: item.filename, kind: .move, status: .inProgress))

            do {
                
                var parentFolderId = item.parentItemIdentifier.rawValue
                
                if item.parentItemIdentifier == .rootContainer {
                    parentFolderId = String(user.root_folder_id)
                }
                
                let folderMeta = try await driveNewAPI.getFolderMetaById(id: parentFolderId)
                let destinationName = folderMeta.plainName ?? folderMeta.name ?? item.parentItemIdentifier.rawValue

                guard let parentUuid = folderMeta.uuid  else {
                    throw UploadFileUseCaseError.InvalidParentUUID
                }
                
                let file = try await driveNewAPI.moveFileNew(uuid: item.itemIdentifier.rawValue, destinationFolder: parentUuid)
                      
                
                let newItem = FileProviderItem(
                    identifier: item.itemIdentifier,
                    filename: item.filename,
                    parentId: item.parentItemIdentifier,
                    createdAt: (item.creationDate ?? Date()) ?? Date(),
                    updatedAt: Date(),
                    itemExtension: file.type,
                    itemType: .file,
                    size: Int(file.size)!
                )
                
                
                self.logger.info("Moving file '\(item.filename)' (\(newItem.itemIdentifier.rawValue)) to '\(destinationName)' (\(item.parentItemIdentifier.rawValue))")
                activityManager.updateActivityEntryStatus(id: trackingId, filename: item.filename, kind: .move, status: .finished)
                completionHandler(newItem, [], false, nil)
                self.logger.info("✅ File '\(item.filename)' moved successfully to '\(destinationName)'")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to move file '\(item.filename)' (uuid: \(item.itemIdentifier.rawValue)): \(error.localizedDescription)")
                activityManager.updateActivityEntryStatus(id: trackingId, filename: item.filename, kind: .move, status: .failed, errorMessage: error.getErrorDescription())
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}

