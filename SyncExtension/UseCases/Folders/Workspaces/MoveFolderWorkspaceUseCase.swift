//
//  MoveFolderWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore


struct MoveFolderWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    let driveNewAPI = APIFactory.DriveWorkspace
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    let workspace: [AvailableWorkspace]
    init(user: DriveUser,item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void,
         workspace : [AvailableWorkspace]) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
        self.workspace = workspace
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Moving folder with id \(item.itemIdentifier.rawValue)")
            
            do {
                
                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    return
                }
                let rootFolderUuid = workspace[0].workspaceUser.rootFolderId
           
                
                let newParentIsRootFolder: Bool = item.parentItemIdentifier == .rootContainer
                _ = try await driveNewAPI.moveFolderNew(uuid: item.itemIdentifier.rawValue, destinationFolder: newParentIsRootFolder == true ? rootFolderUuid : item.parentItemIdentifier.rawValue)
        
      
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

