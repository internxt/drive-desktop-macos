//
//  MoveFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore


struct MoveFileUseCase {
    let logger = syncExtensionLogger
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
                
                
                let folderMeta = try await driveNewAPI.getFolderMetaById(id: item.parentItemIdentifier.rawValue)

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

