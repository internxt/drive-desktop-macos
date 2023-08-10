//
//  TrashFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation

import FileProvider
import InternxtSwiftCore
import os.log

enum TrashFolderUseCaseError: Error {
    case InvalidItemId
    case TrashRequestFailed
}

extension OptionSet {
    func removing(_ element: Element) -> Self {
        var mutable = self
        mutable.remove(element)
        return mutable
    }
}

struct TrashFolderUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "TrashFolder")
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let item: NSFileProviderItem
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let changedFields: NSFileProviderItemFields
    init(item: NSFileProviderItem, changedFields: NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    public func run( ) -> Progress {
        self.logger.info("Moving item to trash")
        Task {
            do {
                var items: Array<ItemToTrash> = Array()
                guard let id = Int(item.itemIdentifier.rawValue) else {
                    throw TrashFolderUseCaseError.InvalidItemId
                }
                items.append(ItemToTrash(
                    id: id,
                    type: .Folder
                ))
                let trashed: Bool = try await trashAPI.trashItems(itemsToTrash: AddItemsToTrashPayload(items: items))
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
                    completionHandler(newItem, changedFields.removing(.parentItemIdentifier), false, nil)
                } else {
                    completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                }
                
            } catch {
                self.logger.error("Failed to trash folder: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
