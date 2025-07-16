//
//  CreateFolderWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 8/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct CreateFolderWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    let driveNewAPI = APIFactory.DriveWorkspace
    let itemTemplate: NSFileProviderItem
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    let workspace: [AvailableWorkspace]
    init(user: DriveUser, itemTemplate: NSFileProviderItem,workspace:[AvailableWorkspace] ,completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.itemTemplate = itemTemplate
        self.user = user
        self.completionHandler = completionHandler
        self.workspace = workspace
    }
    
    
    func run() -> Progress {
        Task {
        
            let workspaceId = workspace[0].workspaceUser.workspaceId
            let rootFolderUuid = workspace[0].workspaceUser.rootFolderId
            let parentFolderUuid = itemTemplate.parentItemIdentifier == .rootContainer  ? rootFolderUuid : itemTemplate.parentItemIdentifier.rawValue
            
            do {
                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    return
                }
                
                let filename = itemTemplate.filename as NSString
                self.logger.info("✅ Parent Folder id to create: \(parentFolderUuid)")

                let createdFolder = try await driveNewAPI.createFolderWorkspace(parentFolderUuid: parentFolderUuid, folderName: filename.deletingPathExtension, workspaceUuid: workspaceId,debug: true)
                completionHandler(FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: createdFolder.uuid),
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
                        let folderResult = try await driveNewAPI.getFolderExistencesInFolder(folderParentUuid: parentFolderUuid, folderName: itemTemplate.filename)

                        
                        if let folder = folderResult.existentFolders.first(where: {
                            $0.plainName == itemTemplate.filename && $0.removed == false
                        }) {
                            completionHandler(FileProviderItem(
                                identifier: NSFileProviderItemIdentifier(rawValue: String(folder.uuid)),
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
