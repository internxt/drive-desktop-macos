//
//  RenameFileWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct RenameFileWorkspaceUseCase {
    let logger = syncExtensionLogger
    let driveNewAPI = APIFactory.DriveWorkspace
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    
    init(user: DriveUser,item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Renaming file with uuid \(item.itemIdentifier.rawValue)")
            
            
            do {
                let filename = (item.filename as NSString)

                let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                
                let updated = try await driveNewAPI.updateFileNew(
                    uuid: fileMeta.uuid,
                    bucketId:  user.bucket,
                    newFilename: filename.deletingPathExtension,
                    debug: true
                )
                
                let createdAt = Time.dateFromISOString(fileMeta.createdAt) ?? Date()
                let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) ?? Date()
                


                let renameItem = FileProviderItem(
                    identifier: item.itemIdentifier,
                    filename: fileMeta.name,
                    parentId: item.parentItemIdentifier,
                    createdAt: createdAt,
                    updatedAt: updatedAt,
                    itemExtension: fileMeta.type,
                    itemType: .file
                )
                
                self.logger.info("✅ File updated successfully")
                completionHandler(renameItem, changedFields.removing(.filename), false, nil)
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to rename file: \(error.getErrorDescription())")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}
