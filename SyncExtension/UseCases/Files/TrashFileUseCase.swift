import Foundation
//
//  TrashFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation

import FileProvider
import InternxtSwiftCore
import os.log

enum TrashFileUseCaseError: Error {
    case InvalidItemId
    case TrashRequestFailed
}


struct TrashFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "TrashFile")
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let item: NSFileProviderItem
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let changedFields: NSFileProviderItemFields
    init(item: NSFileProviderItem, changedFields: NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    public func run( ) -> Progress {
        self.logger.info("Moving file to trash with id \(item.itemIdentifier.rawValue)")
        Task {
            do {
                
                let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
              
                self.logger.info("Trashing file with fileId \(fileMeta.fileId)")
                let trashed: Bool = try await trashAPI.trashFiles(itemsToTrash: [FileToTrash(
                    id: fileMeta.fileId
                )])
                self.logger.info("Trashed file result is: \(trashed)")
                if trashed == true {
                    let newItem = FileProviderItem(
                        identifier: item.itemIdentifier,
                        filename: item.filename,
                        parentId: item.parentItemIdentifier,
                        createdAt: (item.creationDate ?? Date()) ?? Date(),
                        updatedAt: (item.contentModificationDate ?? Date()) ?? Date(),
                        itemExtension: item.contentType?.preferredFilenameExtension,
                        itemType: .file
                    )
                    self.logger.info("✅ File with id \(item.itemIdentifier.rawValue) trashed correctly")
                    completionHandler(newItem, changedFields.removing(.parentItemIdentifier), false, nil)
                    
                } else {
                    throw TrashFileUseCaseError.TrashRequestFailed
                }
                
            } catch {
                self.logger.error("❌ Failed to trash file: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
