//
//  MoveFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import os.log
import FileProvider
import InternxtSwiftCore


struct MoveFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "MoveFile")
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
            self.logger.info("Moving file with uuid \(item.itemIdentifier.rawValue)")
            
            do {
                
                // Grab the file by the uuid, we need the fileId to update it
                let file = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                
                let newParentIsRootFolder: Bool = item.parentItemIdentifier == .rootContainer
                
                _ = try await driveAPI.moveFile(
                    fileId: file.fileId,
                    bucketId: user.bucket,
                    destinationFolder: newParentIsRootFolder == true ? user.root_folder_id : Int(item.parentItemIdentifier.rawValue)!
                )
      
                
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
                
                
                self.logger.info("Moving \(newItem.itemIdentifier.rawValue) to \(item.parentItemIdentifier.rawValue)")
                completionHandler(newItem, [], false, nil)
                self.logger.info("✅ File moved successfully")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to move file: \(error.localizedDescription)")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}
