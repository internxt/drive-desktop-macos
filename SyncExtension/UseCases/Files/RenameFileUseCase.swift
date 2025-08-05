//
//  RenameFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct RenameFileUseCase {
    let logger = syncExtensionLogger
    let driveNewAPI = APIFactory.DriveNew
    let item: NSFileProviderItem
    let changedFields: NSFileProviderItemFields
    let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    let user: DriveUser
    
    init(user: DriveUser,item: NSFileProviderItem, changedFields:  NSFileProviderItemFields, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) {
        self.user = user
        self.item = item
        self.completionHandler = completionHandler
        self.changedFields = changedFields
    }
    
    
    func run() -> Progress {
        Task {
            self.logger.info("Renaming file with uuid \(item.itemIdentifier.rawValue)")
            
            
            do {
                let filename = (item.filename as NSString)
                let updatedDriveFile = try await DriveFileService.shared.renameFile(
                    uuid: item.itemIdentifier.rawValue,
                    bucketId: user.bucket,
                    newName: filename.deletingPathExtension
                )
                
                self.logger.info("✅ File updated successfully")
                completionHandler(updatedDriveFile.fileProviderItem, changedFields.removing(.filename), false, nil)
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to rename file: \(error.localizedDescription)")
                completionHandler(nil, [], false,  NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                
            }
        }
        
        return Progress()
    }
}
