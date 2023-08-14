//
//  CreateFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation
import os.log
import FileProvider
struct CreateFolderUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "CreateFolder")
    let driveAPI = APIFactory.DriveNew
    let itemTemplate: NSFileProviderItem
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    init(itemTemplate: NSFileProviderItem, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.itemTemplate = itemTemplate
        self.completionHandler = completionHandler
    }
    
    
    func run() -> Progress {
        Task {
            let parentFolderId = itemTemplate.parentItemIdentifier == .rootContainer  ? ConfigLoader().get().ROOT_FOLDER_ID : itemTemplate.parentItemIdentifier.rawValue
            
            do {
                guard let parentFolderIdInt = Int(parentFolderId) else {
                    throw CreateItemError.NoParentIdFound
                }
                let createdFolder = try await driveAPI.createFolder(parentFolderId: parentFolderIdInt, folderName: itemTemplate.filename, debug: true)
                self.logger.info("Folder created successfully: \(createdFolder.id)")
                
                
                completionHandler(FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFolder.id)),
                    filename: createdFolder.plain_name ?? createdFolder.name,
                    parentId: itemTemplate.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(createdFolder.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(createdFolder.updatedAt) ?? Date(),
                    itemExtension: nil,
                    itemType: .folder
                ), [], false, nil)
                
            } catch {
                self.logger.error("Failed to create folder: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
