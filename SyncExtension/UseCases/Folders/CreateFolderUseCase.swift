//
//  CreateFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct CreateFolderUseCase {
    let logger = syncExtensionLogger
    let driveAPI = APIFactory.Drive
    let driveNewAPI = APIFactory.DriveNew
    let itemTemplate: NSFileProviderItem
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    init(user: DriveUser, itemTemplate: NSFileProviderItem, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.itemTemplate = itemTemplate
        self.user = user
        self.completionHandler = completionHandler
    }
    
    
    func run() -> Progress {
        Task {
            let parentFolderId = itemTemplate.parentItemIdentifier == .rootContainer  ? user.root_folder_id.toString() : itemTemplate.parentItemIdentifier.rawValue
            
            do {

         
                let filename = itemTemplate.filename as NSString
                self.logger.info("✅ Parent Folder id to create: \(parentFolderId)")
                let folderMeta = try await driveNewAPI.getFolderMetaById(id: parentFolderId,debug: true)
                
                guard let parentUuid = folderMeta.uuid else { throw CreateItemError.NoParentUuidFound }

                let createdFolder = try await driveNewAPI.createFolderNew(parentFolderUuid: parentUuid, folderName: itemTemplate.filename,debug: true)
                
                completionHandler(FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFolder.id)),
                    filename: createdFolder.plainName ?? createdFolder.name,
                    parentId: itemTemplate.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(createdFolder.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(createdFolder.updatedAt) ?? Date(),
                    itemExtension: nil,
                    itemType: .folder
                ), [], false, nil)
                
                self.logger.info("✅ Folder created successfully: \(createdFolder.id)")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to create folder: \(error.getErrorDescription())")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
