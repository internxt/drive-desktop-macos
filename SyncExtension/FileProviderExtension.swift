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
    let logger = Logger(subsystem: "com.internxt", category: "sync")
    let driveAPI: DriveAPI = APIFactory.Drive
    let config = ConfigLoader()
    let manager: NSFileProviderManager
    let tmpURL: URL
    let networkFacade: NetworkFacade
    let user: DriveUser
    let mnemonic: String
    let authManager: AuthManager
    required init(domain: NSFileProviderDomain) {
        self.logger.info("Starting sync extension")

        ErrorUtils.start()
        
        guard let manager = NSFileProviderManager(for: domain) else {
            ErrorUtils.fatal("Cannot get FileProviderManager for domain")
        }
        
        self.manager = manager
        
        self.authManager = AuthManager()
        
        guard let user = authManager.user else {
            ErrorUtils.fatal("Cannot find user in auth manager, cannot initialize extension")
        }
        
        ErrorUtils.identify(email: user.email, uuid: user.uuid)
        
        self.user = user
        
        guard let mnemonic = authManager.mnemonic else {
            ErrorUtils.fatal("Cannot find mnemonic in auth manager, cannot initialize extension")
        }
        
        self.mnemonic = mnemonic
        self.networkFacade = NetworkFacade(mnemonic: self.mnemonic, networkAPI: APIFactory.Network)
        
        do {
            self.tmpURL = try manager.temporaryDirectoryURL()
        } catch {
            ErrorUtils.fatal("Cannot get tmp directory URL, file provider cannot work")
        }
        
        self.logger.info("Created extension with domain \(domain.displayName)")
        super.init()
    }
    
    func checkUpdates() {
        manager.signalEnumerator(for: .rootContainer, completionHandler: {_ in
            self.logger.info("Enumerator signaled")
        })
    }
    
    func makeTemporaryURL(_ purpose: String, _ ext: String? = nil) -> URL {
        if let ext = ext {
            return tmpURL.appendingPathComponent("\(purpose)-\(UUID().uuidString).\(ext)")
        } else {
            return tmpURL.appendingPathComponent("\(purpose)-\(UUID().uuidString)")
        }
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
        
        // We cannot determine given an identifier if this is a folder or a file, so we try both
        return GetFileOrFolderMetaUseCase(
            user: user,
            identifier: identifier,
            completionHandler: completionHandler
        ).run()
    }
    

    
    func fetchContents(for itemIdentifier: NSFileProviderItemIdentifier, version requestedVersion: NSFileProviderItemVersion?, request: NSFileProviderRequest, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) -> Progress {
        // TODO: implement fetching of the contents for the itemIdentifier at the specified version
        
        
        let encryptedFileDestinationURL = makeTemporaryURL("encrypt", "enc")
        let destinationURL = makeTemporaryURL("plain")
        return FetchFileContentUseCase(
            networkFacade: networkFacade,
            user: user,
            itemIdentifier: itemIdentifier,
            encryptedFileDestinationURL: encryptedFileDestinationURL,
            destinationURL: destinationURL,
            completionHandler: completionHandler
        ).run()
    }
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        
        // TODO: a new item was created on disk, process the item's creation
        let shouldCreateFolder = itemTemplate.contentType == .folder
        let shouldCreateFile = !shouldCreateFolder && itemTemplate.contentType != .symbolicLink
        
        if shouldCreateFolder {
            return CreateFolderUseCase(user: user,itemTemplate: itemTemplate, completionHandler: completionHandler).run()
        }
        
        if shouldCreateFile {
            guard let contentUrl = url else {
                self.logger.error("Did not receive content to create file, cannot create")
                return Progress()
            }
            return CreateFileUseCase(
                networkFacade: networkFacade,
                user: user,
                item: itemTemplate,
                url: contentUrl,
                encryptedFileDestination: makeTemporaryURL("encryption", "enc"),
                completionHandler: completionHandler
            ).run()
        }
        
        return Progress()
    }
    
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        
        // Folder cases
        let folderHasBeenTrashed = changedFields.contains(.parentItemIdentifier) && item.parentItemIdentifier == .trashContainer && item.contentType == .folder
        let folderHasBeenRenamed = changedFields.contains(.filename) && item.contentType == .folder
        let folderHasBeenMoved = changedFields.contains(.parentItemIdentifier) && item.contentType == .folder && !folderHasBeenTrashed
        // File cases
        let fileHasBeenTrashed = changedFields.contains(.parentItemIdentifier) && item.parentItemIdentifier == .trashContainer && item.contentType != .folder
        let fileHasBeenRenamed = changedFields.contains(.filename) && item.contentType != .folder
        let fileHasBeenMoved = changedFields.contains(.parentItemIdentifier) && item.contentType != .folder &&  !fileHasBeenTrashed
       
        // File and folder cases
        let contentHasChanged = changedFields.contains(.contents)
        let contentModificationDateHasChanged = changedFields.contains(.contentModificationDate)
        let lastUsedDateHasChanged = changedFields.contains(.lastUsedDate)
        
        self.logger.info("Modification request for item \(item.itemIdentifier.rawValue)")
        
        
        
        
        if folderHasBeenTrashed {
            return TrashFolderUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if folderHasBeenRenamed {
            return RenameFolderUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if folderHasBeenMoved {
            return MoveFolderUseCase(user: user, item:item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if fileHasBeenTrashed {
            return TrashFileUseCase(item: item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if fileHasBeenRenamed  {
            return RenameFileUseCase(user:user,item: item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if fileHasBeenMoved {
            return MoveFileUseCase(user: user, item:item, changedFields: changedFields, completionHandler: completionHandler).run()
        }
        
        if contentHasChanged {
            self.logger.info("File content has changed, let it pass")
            completionHandler(item, [], false, nil)
            return Progress()
        }
        
        if contentModificationDateHasChanged {
            self.logger.info("File content modification date has changed, let it pass")
            completionHandler(item, [], false, nil)
            return Progress()
        }
        
        if lastUsedDateHasChanged {
            let itemExtension = (item.filename as NSString).pathExtension
            let fileProviderItem = FileProviderItem(
                identifier: item.itemIdentifier,
                filename: item.filename,
                parentId: item.parentItemIdentifier,
                createdAt: (item.creationDate ?? Date()) ?? Date(),
                updatedAt: Date(),
                itemExtension: itemExtension,
                itemType: item.contentType == .folder ? .folder : .file
            )
            completionHandler(fileProviderItem, [], false, nil)
            return Progress()
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
        return FileProviderEnumerator(user:user,enumeratedItemIdentifier: containerItemIdentifier)
    }
    
}
