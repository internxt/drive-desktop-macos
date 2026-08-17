//
//  TrashFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import RealmSwift

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
    let logger = syncExtensionLogger
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let item: NSFileProviderItem
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let changedFields: NSFileProviderItemFields
    private let activityManager: ActivityManager

    init(
        item: NSFileProviderItem,
        changedFields: NSFileProviderItemFields,
        activityManager: ActivityManager,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) {
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
        self.activityManager = activityManager
    }
    
    public func run() -> Progress {
        self.logger.info("Moving item to trash")
        let trackingId = ObjectId.generate()
        Task {
            do {
               
                guard let id = Int(item.itemIdentifier.rawValue) else {
                    throw TrashFolderUseCaseError.InvalidItemId
                }

                activityManager.saveActivityEntry(entry: ActivityEntry(_id: trackingId, filename: item.filename, kind: .trash, status: .inProgress))
               
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
                    activityManager.updateActivityEntryStatus(id: trackingId, filename: item.filename, kind: .trash, status: .finished)
                    DeletedFolderCache.shared.markFolderAsDeleted(String(id))
                    completionHandler(newItem, changedFields.removing(.parentItemIdentifier), false, nil)
                } else {
                    throw TrashFolderUseCaseError.RequestNotSuccessful
                }
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to trash folder: \(error.localizedDescription)")
                activityManager.updateActivityEntryStatus(id: trackingId, filename: item.filename, kind: .trash, status: .failed, errorMessage: error.getErrorDescription())
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
