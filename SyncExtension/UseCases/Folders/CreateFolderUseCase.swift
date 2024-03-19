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
    let logger = LogService.shared.createLogger(subsystem: .SyncExtension, category: "CreateFolder")
    let driveAPI = APIFactory.Drive
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
            print("TOKEN", await ConfigLoader.shared.getLegacyAuthToken())
            let parentFolderId = itemTemplate.parentItemIdentifier == .rootContainer  ? user.root_folder_id.toString() : itemTemplate.parentItemIdentifier.rawValue
            
            do {
                guard let parentFolderIdInt = Int(parentFolderId) else {
                    throw CreateItemError.NoParentIdFound
                }
                
                let filename = itemTemplate.filename as NSString
                
                let createdFolder = try await driveAPI.createFolder(parentFolderId: parentFolderIdInt, folderName: filename.deletingPathExtension, debug: true)

                completionHandler(FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFolder.id)),
                    filename: createdFolder.plain_name ?? createdFolder.name,
                    parentId: itemTemplate.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(createdFolder.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(createdFolder.updatedAt) ?? Date(),
                    itemExtension: nil,
                    itemType: .folder
                ), [], false, nil)
                
                self.logger.info("✅ Folder created successfully: \(createdFolder.id)")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to create folder: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
