//
//  TrashFolderWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 9/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore



struct TrashFolderWorkspaceUseCase {
    let logger = syncExtensionLogger
    private let trashAPI: TrashAPI = APIFactory.TrashWorkspace
    private let item: NSFileProviderItem
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let changedFields: NSFileProviderItemFields
    init(item: NSFileProviderItem, changedFields: NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    public func run() -> Progress {
        self.logger.info("Moving item to trash")
        Task {
            do {
               
 
                let trashed: Bool = try await trashAPI.trashFoldersByUuid(itemsToTrash: [FolderToTrashV2(uuid: item.itemIdentifier.rawValue)])
                self.logger.info("Trashed item result is: \(trashed)")
                if trashed == true {
                    let newItem = FileProviderItem(
                        identifier: item.itemIdentifier,
                        filename: item.filename,
                        parentId: item.parentItemIdentifier,
                        // TODO: Improve how we handle this, an item should have a creationDate always
                        createdAt: (item.creationDate ?? Date()) ?? Date(),
                        updatedAt: (item.contentModificationDate ?? Date()) ?? Date(),
                        itemExtension: nil,
                        itemType: .folder
                    )
                    self.logger.info("✅ Folder with id \(item.itemIdentifier.rawValue) trashed correctly")
                    completionHandler(newItem, changedFields.removing(.parentItemIdentifier), false, nil)
                } else {
                    throw TrashFolderUseCaseError.RequestNotSuccessful
                }
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to trash folder: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
