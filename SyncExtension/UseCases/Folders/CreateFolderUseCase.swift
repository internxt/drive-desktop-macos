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
    let driveNewAPI = APIFactory.DriveNew
    let itemTemplate: NSFileProviderItem
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    let parentUUID: String
    init(user: DriveUser, itemTemplate: NSFileProviderItem,parentUuid: String ,completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.itemTemplate = itemTemplate
        self.user = user
        self.completionHandler = completionHandler
        self.parentUUID = parentUuid
    }
    
    
    func run() -> Progress {
        Task {
            let parentFolderId = itemTemplate.parentItemIdentifier == .rootContainer  ? user.root_folder_id.toString() : itemTemplate.parentItemIdentifier.rawValue
            
            do {

         
                let filename = itemTemplate.filename as NSString
                self.logger.info("✅ Parent Folder id to create: \(parentFolderId) itemname: \(filename)")
             
                let createdFolder = try await driveNewAPI.createFolderNew(parentFolderUuid: parentUUID, folderName: itemTemplate.filename,debug: true)
                
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
                
                if let apiClientError = error as? APIClientError, apiClientError.statusCode == 409 {
                    // Handle duplicated folder error
                    do {
                        let folderResult = try await driveNewAPI.getFolderExistencesInFolder(folderParentUuid: parentUUID, folderName: itemTemplate.filename)

                        
                        if let folder = folderResult.existentFolders.first(where: {
                            $0.plainName == itemTemplate.filename && $0.removed == false
                        }) {
                            completionHandler(FileProviderItem(
                                identifier: NSFileProviderItemIdentifier(rawValue: String(folder.id)),
                                filename: folder.plainName,
                                parentId: itemTemplate.parentItemIdentifier,
                                createdAt: Time.dateFromISOString(folder.createdAt) ?? Date(),
                                updatedAt: Time.dateFromISOString(folder.updatedAt) ?? Date(),
                                itemExtension: nil,
                                itemType: .folder
                            ), [], false, nil)
                        }
                        
                    } catch {
                        self.logger.error("❌ Failed to get folder: \(error.getErrorDescription())")
                        completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                    }
                }else {
                    error.reportToSentry()
                    self.logger.error("❌ Failed to create folder: \(error.getErrorDescription())")
                    completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                }
                
                

            }
        }
        
        return Progress()
    }
}
