//
//  MoveFileWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore


struct MoveFileWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    let driveNewAPI = APIFactory.DriveWorkspace
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    private let workspace: [AvailableWorkspace]
    init(user: DriveUser,item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void,
         workspace: [AvailableWorkspace]    ) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
        self.workspace = workspace
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Moving file with uuid \(item.itemIdentifier.rawValue)")
            self.logger.info("Parent Identifier :  \( item.parentItemIdentifier.rawValue)")
            do {
                
                
                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    return
                }

                var parentFolderUuid = item.parentItemIdentifier.rawValue
                
                if item.parentItemIdentifier == .rootContainer {
                    parentFolderUuid =  workspace[0].workspaceUser.rootFolderId
                }
                
                let file = try await driveNewAPI.moveFileNew(uuid: item.itemIdentifier.rawValue, destinationFolder: parentFolderUuid)
                      
                
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
                self.logger.error("❌ Failed to move file: \(error.getErrorDescription())")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}

