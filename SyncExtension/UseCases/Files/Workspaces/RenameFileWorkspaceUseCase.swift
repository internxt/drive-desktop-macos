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
    let workspaceCredentials: WorkspaceCredentialsResponse
    init(user: DriveUser,item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void, workspaceCredentials: WorkspaceCredentialsResponse) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
        self.workspaceCredentials = workspaceCredentials
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Renaming file with uuid \(item.itemIdentifier.rawValue)")
            
            
            do {
                let filename = (item.filename as NSString)

                let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                
                _ = try await driveNewAPI.updateFileNew(
                    uuid: fileMeta.uuid,
                    bucketId:  workspaceCredentials.bucket,
                    newFilename: filename.deletingPathExtension,
                    debug: true
                )
                
                let createdAt = Time.dateFromISOString(fileMeta.createdAt) ?? Date()
                let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) ?? Date()
                


                let renameItem = FileProviderItem(
                    identifier: item.itemIdentifier,
                    filename: item.filename,
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
