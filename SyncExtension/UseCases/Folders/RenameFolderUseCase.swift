//
//  RenameFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 9/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct RenameFolderUseCase {
    let logger = syncExtensionLogger
    let driveAPIWorkspace = APIFactory.DriveWorkspace
    let driveNewAPI = APIFactory.DriveNew
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    init(item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Renaming folder with id \(item.itemIdentifier.rawValue)")
            let newItem = FileProviderItem(
                identifier: item.itemIdentifier,
                filename: item.filename,
                parentId: item.parentItemIdentifier,
                createdAt: (item.creationDate ?? Date()) ?? Date(),
                updatedAt: Date(),
                itemExtension: nil,
                itemType: .folder
            )
            do {
                
                let folderUuid: String

                if UUID(uuidString: item.itemIdentifier.rawValue) != nil {
                   
                    folderUuid = item.itemIdentifier.rawValue
                    
                    _ = try await driveAPIWorkspace.updateFolderNew(folderUuid: folderUuid, folderName:item.filename, debug: true)
                } else {
                   
                    let folderMeta = try await driveNewAPI.getFolderMetaById(id: item.itemIdentifier.rawValue)
                    
                    guard let parentUuid = folderMeta.uuid else {
                        throw UploadFileUseCaseError.InvalidParentUUID
                    }
                    folderUuid = parentUuid
                    
                    _ = try await driveNewAPI.updateFolderNew(folderUuid: folderUuid, folderName:item.filename, debug: true)
                }

                self.logger.info("✅ Folder with id \(item.itemIdentifier.rawValue) renamed successfully")
                completionHandler(newItem, changedFields.removing(.filename), false, nil)
            } catch {
                error.reportToSentry()
                
                if error is APIClientError {
                    let statusCode = (error as! APIClientError).statusCode
                    self.logger.info("Received status code \(statusCode)")
                    
                    // Local filename is conflicting with remote filename because is the same, we'll let it pass
                    // since this can happen when local is not yet updated with remote changes
                    if statusCode == 409 {
                        completionHandler(newItem, [], false, nil)
                    } else {
                        self.logger.error("❌ Failed to rename folder: \(error.getErrorDescription())")
                        completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                    }
                   
                } else {
                    self.logger.error("❌ Failed to rename folder: \(error.localizedDescription)")
                    completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                }
                
            }
        }
        
        return Progress()
    }
}
