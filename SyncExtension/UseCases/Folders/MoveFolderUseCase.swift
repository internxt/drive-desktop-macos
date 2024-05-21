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
            self.logger.info("Moving folder with id \(item.itemIdentifier.rawValue)")
            
            do {
                
                
                let folder = try await driveNewAPI.getFolderMetaById(id: item.itemIdentifier.rawValue)
                
                let newParentIsRootFolder: Bool = item.parentItemIdentifier == .rootContainer
                
                _ = try await driveAPI.moveFolder(
                    folderId: folder.id,
                    destinationFolder: newParentIsRootFolder == true ? user.root_folder_id : Int(item.parentItemIdentifier.rawValue)!
                )
      
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

