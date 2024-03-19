//
//  TrashFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

enum TrashFolderUseCaseError: Error {
    case InvalidItemId
    case TrashRequestFailed
    case RequestNotSuccessful
}

extension OptionSet {
    func removing(_ element: Element) -> Self {
        var mutable = self
        mutable.remove(element)
        return mutable
    }
}

struct TrashFolderUseCase {
    let logger = LogService.shared.createLogger(subsystem: .SyncExtension, category: "TrashFolder")
    private let trashAPI: TrashAPI = APIFactory.Trash
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
               
                guard let id = Int(item.itemIdentifier.rawValue) else {
                    throw TrashFolderUseCaseError.InvalidItemId
                }
               
                let trashed: Bool = try await trashAPI.trashFolders(itemsToTrash: [FolderToTrash(id: id)])
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
