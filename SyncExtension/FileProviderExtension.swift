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
        self.logger.info("Creating domain \(domain.displayName)")
        // TODO: The containing application must create a domain using `NSFileProviderManager.add(_:, completionHandler:)`. The system will then launch the application extension process, call `FileProviderExtension.init(domain:)` to instantiate the extension for that domain, and call methods on the instance.
        super.init()
    }
    
    func invalidate() {
        // TODO: cleanup any resources
    }
    
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        // resolve the given identifier to a record in the model
        
        // TODO: implement the actual lookup
        
        
        if identifier == .trashContainer {
            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: .trashContainer))
            
            return Progress()
        }
        
        if identifier == .workingSet {
            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: .workingSet))
            
            return Progress()
        }
        Task {
            do {
                let folderId = identifier == .rootContainer ? "69934033" : identifier.rawValue
                let folderContent = try await self.driveAPI.getFolderContent(folderId: folderId, debug:true)
                logger.info("Got folder content for item")
                
                let createdAtDateFormatter = DateFormatter()
                createdAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                
                let updatedAtDateFormatter = DateFormatter()
                updatedAtDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
              
                let item = FileProviderItem(
                    identifier: identifier,
                    filename: folderContent.plain_name ?? folderContent.name,
                    parentId: folderContent.parentId != nil ? NSFileProviderItemIdentifier(String(folderContent.parentId!)) : .rootContainer,
                    createdAt: Date(),
                    updatedAt: Date(),
                    itemExtension: nil,
                    itemType: .folder
                )
                
                
                completionHandler(item, nil)
                logger.info("Sent folder content")
            } catch {
                logger.error("Got error while replying for item")
                completionHandler(nil, error)
            }
            
        }
        
        return Progress()
    }
    
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        // TODO: implement fetching of the contents for the itemIdentifier at the specified version
        
        completionHandler(nil, nil, NSError(domain: NSCocoaErrorDomain, code: NSFeatureUnsupportedError, userInfo:[:]))
        return Progress()
    }
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        // TODO: a new item was created on disk, process the item's creation
        self.logger.info("DRIVE CREATE NEW ITEM: \(itemTemplate.filename) \(itemTemplate.contentType?.identifier ?? "NO_TYPE") \(itemTemplate.parentItemIdentifier.rawValue)  ")
        
        if (itemTemplate.contentType == .folder) {
            // TODO: Move this to CreateFolderUseCase
            Task {
                let parentFolderId = itemTemplate.parentItemIdentifier == .rootContainer  ? "69934033" : itemTemplate.parentItemIdentifier.rawValue
                
                do {
                    guard let parentFolderIdInt = Int(parentFolderId) else {
                        throw CreateItemError.NoParentIdFound
                    }
                    let createdFolder = try await driveAPI.createFolder(parentFolderId: parentFolderIdInt, folderName: itemTemplate.filename, debug: true)
                    self.logger.info("Folder created successfully: \(createdFolder.id)")
                    
                    
                    completionHandler(FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(createdFolder.id)),
                        filename: createdFolder.plain_name ?? createdFolder.name,
                        parentId: itemTemplate.parentItemIdentifier,
                        createdAt: Date(),
                        updatedAt: Date(),
                        itemExtension: nil,
                        itemType: .folder
                    ), [], false, nil)
                } catch {
                    
                    self.logger.error("Failed to create folder: \(error.localizedDescription)")
                    completionHandler(nil, [], false, error)
                }
                
                
            }
        }
        
        return Progress()
    }
    
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        self.logger.info("Modification request for item \(item.itemIdentifier.rawValue)")
        
        if changedFields.contains(.filename) {
            // TODO: Move this task to an UseCase
            self.logger.info("Modified filename, new one is \(item.filename)")
            Task {
                
                do {
                    try await driveAPI.updateFolder(folderId: item.itemIdentifier.rawValue, folderName:item.filename, debug: true)
                    self.logger.info("Folder updated successfully")
                    completionHandler(item, [], false, nil)
                } catch {
                    if error is APIClientError {
                        let statusCode = (error as! APIClientError).statusCode
                        // Local filename is conflicting with remote filename, we'll let it pass
                        if statusCode == 409 {
                            completionHandler(item, [], false, nil)
                        }
                       
                    } else {
                        self.logger.error("Failed to create folder: \(error.localizedDescription)")
                        completionHandler(nil, [], false, error)
                    }
                    
                }
            }
            return Progress()
        }
        
                
        self.logger.info("Item modification wasn't handled if this message appear: item -> \(item.description)")
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
