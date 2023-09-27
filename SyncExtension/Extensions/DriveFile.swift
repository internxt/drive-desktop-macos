//
//  DriveFile.swift
//  SyncExtension
//
//  Created by Robert Garcia on 26/9/23.
//

import Foundation
import FileProvider

extension DriveFile {
    var fileProviderItem: FileProviderItem {
        let config = ConfigLoader.shared
        
        guard let user = config.getUser() else {
            ErrorUtils.fatal("User not found while creating a fileProviderItem from a driveItem")
        }
        
        let parentIsRoot = user.root_folder_id == self.folderId
        
        let filename = FileProviderItem.getFilename(name: self.plainName ?? self.name, itemExtension: self.type)
        
        func getParentId() -> NSFileProviderItemIdentifier {
            if self.status == .trashed {
                return .trashContainer
            }
            if parentIsRoot {
                return .rootContainer
            }
            
            return NSFileProviderItemIdentifier(folderId.toString())
        }
        
        return FileProviderItem(
            identifier: NSFileProviderItemIdentifier(self.uuid),
            filename: filename,
            parentId: getParentId(),
            createdAt: self.createdAt,
            updatedAt: self.updatedAt,
            itemExtension: self.type,
            itemType: .file
        )
    }
}
