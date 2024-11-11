//
//  MoveFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore


struct MoveFolderUseCase {
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
            self.logger.info("Moving folder with id \(item.itemIdentifier.rawValue)")
            
            do {
                let newParentIsRootFolder: Bool = item.parentItemIdentifier == .rootContainer
                
                let folder = try await driveNewAPI.getFolderMetaById(id: item.itemIdentifier.rawValue)
                let folderDestination =  try await driveNewAPI.getFolderMetaById(id: newParentIsRootFolder == true ? String(user.root_folder_id) : item.parentItemIdentifier.rawValue)
                
                guard let parentUuid = folder.uuid  else {
                    throw UploadFileUseCaseError.InvalidParentUUID
                }
                
                guard let parentUuidDestination = folderDestination.uuid  else {
                    throw UploadFileUseCaseError.InvalidParentUUID
                }
                
                
                _ = try await driveNewAPI.moveFolderNew(uuid: parentUuid, destinationFolder: parentUuidDestination)
                      
                let newItem = FileProviderItem(
                    identifier: item.itemIdentifier,
                    filename: item.filename,
                    parentId: item.parentItemIdentifier,
                    createdAt: (item.creationDate ?? Date()) ?? Date(),
                    updatedAt: Date(),
                    itemExtension: nil,
                    itemType: .folder
                )
                
                completionHandler(newItem, [], false, nil)
                self.logger.info("✅ Folder moved successfully")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to move folder: \(error.localizedDescription)")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}

