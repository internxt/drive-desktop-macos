//
//  FileProviderExtension.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import os.log
import InternxtSwiftCore

enum CreateItemError: Error {
    case NoParentIdFound
}
class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension {
    let logger = Logger(subsystem: "com.internxt", category: "SyncExtension")
    let driveAPI: DriveAPI = APIFactory.Drive
    let config = ConfigLoader()
    required init(domain: NSFileProviderDomain) {
        config.load()
        self.logger.info("Created extension with domain \(domain.displayName)")
        super.init()
    }
    

    
    func invalidate() {
        // TODO: cleanup any resources
    }
    
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        // resolve the given identifier to a record in the model
        
        self.logger.info("Getting item metadata for \(identifier.rawValue)")
        if identifier == .trashContainer {
            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: .trashContainer))
            
            return Progress()
        }
        
        if identifier == .workingSet {
            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: .workingSet))
            
            return Progress()
        }
        
        if identifier == .rootContainer {
            completionHandler(FileProviderItem(
                identifier: identifier,
                filename: "ROOT",
                parentId: .rootContainer,
                createdAt: Date(),
                updatedAt: Date(),
                itemExtension: nil,
                itemType: .folder
                
            ), nil)
            
            return Progress()
        }
        
        // Assume is a folder
        
        return GetFolderMetaUseCase(identifier: identifier, completionHandler: completionHandler).run()
    }
    
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        // TODO: implement fetching of the contents for the itemIdentifier at the specified version
        
        completionHandler(nil, nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
        return Progress()
    }
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        // TODO: a new item was created on disk, process the item's creation
        // Create a folder
        if (itemTemplate.contentType == .folder) {
            return CreateFolderUseCase(itemTemplate: itemTemplate, completionHandler: completionHandler).run()
        }
        
        return Progress()
    }
    
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        self.logger.info("Modification request for item \(item.itemIdentifier.rawValue)")
        
        
        if changedFields.contains(.contents) {
            self.logger.info("File content has changed")
        }
        
        if changedFields.contains(.contentModificationDate) {
            self.logger.info("File content modification date has changed")
        }
        
        if changedFields.contains(.lastUsedDate) {
            self.logger.info("File last used date has changed")
        }
        
        // User moved item to trash
        if changedFields.contains(.parentItemIdentifier) && item.parentItemIdentifier == .trashContainer && item.contentType != nil {
            switch item.contentType! {
                case .folder:
                    return TrashFolderUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
                default:
                    return TrashFileUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
            }
            
        }
        
        // User renamed a folder
        if changedFields.contains(.filename) && item.contentType == .folder {
            self.logger.info("Modified folder filename, new one is \(item.filename)")
            
            return RenameFolderUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if changedFields.contains(.filename) && item.contentType != .folder  {
            self.logger.info("Modified file filename, new one is \(item.filename)")
        }
                
        self.logger.info("Item modification wasn't handled if this message appear: item -> \(item.filename)")
        return Progress()
    }
    
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        self.logger.info("Delete request for item \(identifier.rawValue)")
        // TODO: an item was deleted on disk, process the item's deletion
        
        
        completionHandler(NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
        return Progress()
    }
    
    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(enumeratedItemIdentifier: containerItemIdentifier)
    }
}
