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

enum TrashFileUseCaseError: Error {
    case InvalidItemId
    case TrashRequestFailed
}


struct TrashFileUseCase {
    let logger = syncExtensionLogger
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
        Task {
            do {
                self.logger.info("Trashing file with id \(item.itemIdentifier.rawValue)")
                let driveFileTrashed = try await DriveFileService.shared.trashFile(uuid: item.itemIdentifier.rawValue)
                self.logger.info("✅ File with id \(item.itemIdentifier.rawValue) trashed correctly")
                completionHandler(driveFileTrashed.fileProviderItem, changedFields.removing(.parentItemIdentifier), false, nil)
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to trash file: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
