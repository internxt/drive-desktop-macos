//
//  TrashFileWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore




struct TrashFileWorkspaceUseCase {
    let logger = syncExtensionLogger
    private let trashAPI: TrashAPI = APIFactory.TrashWorkspace
    private let driveNewAPI: DriveAPI = APIFactory.DriveWorkspace
    private let item: NSFileProviderItem
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let changedFields: NSFileProviderItemFields
    init(item: NSFileProviderItem, changedFields: NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    public func run( ) -> Progress {
        Task {
            do {
                self.logger.info("Trashing file with id \(item.itemIdentifier.rawValue)")
             
                let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                
                
                let trashed: Bool = try await trashAPI.trashItemsByUuid(itemsToTrash: [ItemToTrashV2(
                    uuid: item.itemIdentifier.rawValue, type: .File
                )])
                
                if trashed == false {
                    throw DriveFileError.TrashNotSuccess
                }
                
                let createdAt = Time.dateFromISOString(fileMeta.createdAt) ?? Date()
                let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) ?? Date()
                
                
                
                
                let newItem = FileProviderItem(
                    identifier: item.itemIdentifier,
                    filename: item.filename,
                    parentId: trashed ? .trashContainer : item.parentItemIdentifier,
                    createdAt: (createdAt),
                    updatedAt: (updatedAt),
                    itemExtension: fileMeta.type,
                    itemType: .file
                )
            
                self.logger.info("✅ File with id \(item.itemIdentifier.rawValue) trashed correctly")
                
                
                
                completionHandler(newItem, changedFields.removing(.parentItemIdentifier), false, nil)
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to trash file: \(error.getErrorDescription())")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
