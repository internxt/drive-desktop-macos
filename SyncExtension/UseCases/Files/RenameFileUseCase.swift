//
//  RenameFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation
import os.log
import FileProvider
import InternxtSwiftCore

struct RenameFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "RenameFile")
    let driveAPI = APIFactory.Drive
    let driveNewAPI = APIFactory.DriveNew
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
            let filename = (item.filename as NSString)
            let newItem = FileProviderItem(
                identifier: item.itemIdentifier,
                filename: item.filename,
                parentId: item.parentItemIdentifier,
                createdAt: (item.creationDate ?? Date()) ?? Date(),
                updatedAt: Date(),
                itemExtension: nil,
                itemType: .file
            )
            do {
                
                // Grab the file by the uuid, we need the fileId to update it
                let file = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                
                _ = try await driveAPI.updateFile(
                    fileId: file.fileId,
                    bucketId:user.bucket,
                    newFilename: filename.deletingPathExtension,
                    debug: false
                )
                self.logger.info("✅ File updated successfully")
                completionHandler(newItem, changedFields.removing(.filename), false, nil)
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to rename file: \(error.localizedDescription)")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}
