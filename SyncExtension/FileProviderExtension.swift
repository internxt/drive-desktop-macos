//
//  FileProviderExtension.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import os.log
import InternxtSwiftCore
import Combine
import Foundation

enum CreateItemError: Error {
    case NoParentIdFound
}


let useIntervalSignaller = true;

let logger = Logger(subsystem: "com.internxt", category: "sync")
class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension, NSFileProviderCustomAction {
    let fileProviderItemActions = FileProviderItemActionsManager()
    let config = ConfigLoader()
    let manager: NSFileProviderManager
    let tmpURL: URL
    let networkFacade: NetworkFacade
    let user: DriveUser
    let mnemonic: String
    let authManager: AuthManager
    let realtimeFallbackTimer: AnyCancellable
    let realtime: RealtimeService
    let activityManager: ActivityManager
    required init(domain: NSFileProviderDomain) {
        
        logger.info("Starting sync extension with version \(Bundle.version())")
        ErrorUtils.start()
        
        self.activityManager = ActivityManager()
        guard let manager = NSFileProviderManager(for: domain) else {
            ErrorUtils.fatal("Cannot get FileProviderManager for domain")
        }
        

        self.manager = manager
        
        self.authManager = AuthManager()
        
        guard let user = authManager.user else {
            ErrorUtils.fatal("Cannot find user in auth manager, cannot initialize extension")
        }
        
        
        
        let realtime = RealtimeService(
            token: self.config.getLegacyAuthToken()!,
            onEvent: {
                Task {
                    do {
                        
                        // Wait 500ms before asking for updates
                        try await Task.sleep(nanoseconds: 500_000_000)
                        try await manager.signalEnumerator(for: .workingSet)
                        logger.info("✅ Signalled enumerator from realtime event")
                    } catch {
                        error.reportToSentry()
                        logger.error("Failed to signal enumerator")
                    }
                    
                }
                
            }
        )
        
        self.realtime = realtime
        
        
        self.realtimeFallbackTimer = Timer.publish(every: 5, on:.main, in: .common).autoconnect().sink(
            receiveValue: {_ in
                
            // If the realtime socket gets disconnected, we will fallback to
            // checking for updates periodically until it gets reconnected
            logger.info("About to signal enumerator to ask for changes")
            logger.info("Realtime is connected: \(realtime.isConnected == true ? "Yes" : "No")")
            if realtime.isConnected == false && useIntervalSignaller {
                manager.signalEnumerator(for: .workingSet, completionHandler: {error in
                    if error != nil {
                        logger.error("Failed to signal enumerator")
                    } else {
                        logger.info("✅ Signalled enumerator from fallback timer because realtime service is not connected")
                    }
                    
                    
                })
            }
        })
        
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
        
        logger.info("Created extension with domain \(domain.displayName)")
        super.init()
        
        do {
            try self.cleanTmpDirectory()
            logger.info("✅ TMP directory cleaned")
        } catch{
            logger.error("Failed to clean TMP directory before starting")
            error.reportToSentry()
        }
        manager.signalEnumerator(for: .workingSet, completionHandler: {error in
            if error != nil {
                logger.error("Failed to signal enumerator")
            } else {
                logger.info("✅ Initially signalled enumerator to ask for changes")
            }
            
            
        })
    }
    
    func cleanTmpDirectory() throws {
        let files = try FileManager.default.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil)
        
        try files.forEach{fileUrl in
            try FileManager.default.removeItem(at: fileUrl)
        }
    }
    
    func checkUpdates() {
        manager.signalEnumerator(for: .rootContainer, completionHandler: {_ in
            logger.info("Enumerator signaled")
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
        fileProviderItemActions.clean()
    }
    
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        // resolve the given identifier to a record in the model
        
        logger.info("Getting item metadata for \(identifier.rawValue)")
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
        
        
        
        let encryptedFileDestinationURL = makeTemporaryURL("encrypt", "enc")
        let destinationURL = makeTemporaryURL("plain")
        
        func internalCompletionHandler(url: URL?, item: NSFileProviderItem?, error: Error?) -> Void {
            
            completionHandler(url, item, error)
            do {
                try FileManager.default.removeItem(at: encryptedFileDestinationURL)
            } catch {
                error.reportToSentry()
            }
            
        }
        return DownloadFileUseCase(
            networkFacade: networkFacade,
            user: user,
            activityManager: activityManager,
            itemIdentifier: itemIdentifier,
            encryptedFileDestinationURL: encryptedFileDestinationURL,
            destinationURL: destinationURL,
            completionHandler: internalCompletionHandler
        ).run()
    }
    
    
    
    func createItem(basedOn itemTemplate: NSFileProviderItem, fields: NSFileProviderItemFields, contents url: URL?, options: NSFileProviderCreateItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        let shouldCreateFolder = itemTemplate.contentType == .folder
        let shouldCreateFile = !shouldCreateFolder && itemTemplate.contentType != .symbolicLink
                
        
        if shouldCreateFolder {
            return CreateFolderUseCase(user: user,itemTemplate: itemTemplate, completionHandler: completionHandler).run()
        }
        
        if shouldCreateFile {
            guard let contentUrl = url else {
                logger.error("Did not receive content to create file, cannot create")
                return Progress()
            }
            
           
            let filename = NSString(string:itemTemplate.filename)
            let fileCopy = makeTemporaryURL("plain", filename.pathExtension)
            try! FileManager.default.copyItem(at: contentUrl, to: fileCopy)
            
            let encryptedFileDestination =  makeTemporaryURL("encrypted", "enc")
            let thumbnailFileDestination = makeTemporaryURL("thumbnail", "jpg")
            let encryptedThumbnailFileDestination = makeTemporaryURL("encrypted_thumbnail", "enc")
            
            func completionHandlerInternal(_ item: NSFileProviderItem?, _ fields: NSFileProviderItemFields, _ shouldFetch:Bool, _ error:Error?) -> Void {
                
                completionHandler(item, fields, shouldFetch, error)
                
               
                do {
                    try FileManager.default.removeItem(at: fileCopy)
                    try FileManager.default.removeItem(at: encryptedFileDestination)
                    try FileManager.default.removeItem(at: encryptedThumbnailFileDestination)
                    try FileManager.default.removeItem(at: thumbnailFileDestination)
                } catch {
                    error.reportToSentry()
                }
                
            }
            
           
            return UploadFileOrUpdateContentUseCase(
                networkFacade: networkFacade,
                user: user,
                activityManager: activityManager,
                item: itemTemplate,
                url: fileCopy,
                encryptedFileDestination: encryptedFileDestination,
                thumbnailFileDestination: thumbnailFileDestination,
                encryptedThumbnailFileDestination: encryptedThumbnailFileDestination,
                completionHandler: completionHandlerInternal
            ).run()
        }
        
        return Progress()
    }
    
    func modifyItem(_ item: NSFileProviderItem, baseVersion version: NSFileProviderItemVersion, changedFields: NSFileProviderItemFields, contents newContents: URL?, options: NSFileProviderModifyItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void) -> Progress {
        
        
        if changedFields.contains(.extendedAttributes) {
            logger.info("Checking extended attributes \(item.filename)")
            let filename = item.filename as NSString
            let item = FileProviderItem(
                identifier: item.itemIdentifier,
                filename: item.filename,
                parentId: item.parentItemIdentifier,
                createdAt: (item.creationDate ?? Date()) ?? Date(),
                updatedAt: (item.contentModificationDate ?? Date()) ?? Date(),
                itemExtension: filename.pathExtension,
                itemType: item.contentType == .folder ? .folder : .file
            )
            completionHandler(item, [.parentItemIdentifier], false, nil)
            
            return Progress()
        }
        
        // Folder cases
        let folderHasBeenTrashed = changedFields.contains(.parentItemIdentifier) && item.parentItemIdentifier == .trashContainer && item.contentType == .folder
        let folderHasBeenRenamed = changedFields.contains(.filename) && item.contentType == .folder
        let folderHasBeenMoved = changedFields.contains(.parentItemIdentifier) && item.contentType == .folder && !folderHasBeenTrashed
        
        // File cases
        let fileHasBeenTrashed = changedFields.contains(.parentItemIdentifier) && item.parentItemIdentifier == .trashContainer && item.contentType != .folder
        let fileHasBeenRenamed = changedFields.contains(.filename) && item.contentType != .folder
        let fileHasBeenMoved = changedFields.contains(.parentItemIdentifier) && item.contentType != .folder &&  !fileHasBeenTrashed
       
        // File and folder cases
        let contentHasChanged = changedFields.contains(.contents) && newContents != nil
        let contentModificationDateHasChanged = changedFields.contains(.contentModificationDate)
        let lastUsedDateHasChanged = changedFields.contains(.lastUsedDate)
        
        logger.info("Modification request for item \(item.itemIdentifier.rawValue)")
        
        
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
            
            let encryptedFileDestination = makeTemporaryURL("enc-\(item.itemIdentifier.rawValue)")
            
            func completionHandlerInternal(item: NSFileProviderItem?, fields: NSFileProviderItemFields, shouldFetch: Bool, error: Error?) -> Void{
                completionHandler(item, fields, shouldFetch, error)
                do {
                    try FileManager.default.removeItem(at: encryptedFileDestination)
                } catch {
                    error.reportToSentry()
                }
            }
            
            return UpdateFileContentUseCase(
                networkFacade: self.networkFacade,
                user: self.user,
                item: item,
                fileUuid: item.itemIdentifier.rawValue,
                url: newContents!,
                encryptedFileDestination: encryptedFileDestination,
                completionHandler: completionHandlerInternal,
                progress: Progress(totalUnitCount: 100)
            ).run()
        }
        
        if contentModificationDateHasChanged {
            logger.info("File content modification date has changed, let it pass")
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
                
        logger.info("Item modification wasn't handled if this message appear: item -> \(item.filename)")
        return Progress()
    }
    
    func deleteItem(identifier: NSFileProviderItemIdentifier, baseVersion version: NSFileProviderItemVersion, options: NSFileProviderDeleteItemOptions = [], request: NSFileProviderRequest, completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        return DeleteFileUseCase(identifier: identifier, completionHandler: completionHandler).run()
    }
    
    func enumerator(for containerItemIdentifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest) throws -> NSFileProviderEnumerator {
        return FileProviderEnumerator(user:user,enumeratedItemIdentifier: containerItemIdentifier)
    }
    
    func performAction(identifier actionIdentifier: NSFileProviderExtensionActionIdentifier, onItemsWithIdentifiers itemIdentifiers: [NSFileProviderItemIdentifier], completionHandler: @escaping (Error?) -> Void) -> Progress {
        
        if actionIdentifier == FileProviderItemActionsManager.RefreshContent {
            logger.info("User requested to refresh content, signalling enumerator...")
            manager.signalEnumerator(for: .workingSet, completionHandler: {error in
                if error == nil {
                    logger.info("Enumerator signalled correctly")
                } else {
                    logger.info("Failed to signal enumerator")
                }
                
                completionHandler(error)
            })
            
            return Progress()
        }
        
        if actionIdentifier == FileProviderItemActionsManager.MakeAvailableOffline {
            Task {
                
                for identifier in itemIdentifiers {
                    fileProviderItemActions.makeAvailableOffline(identifier: identifier)
                    if #available(macOSApplicationExtension 13.0, *) {
                        try await manager.requestModification(of: [.extendedAttributes], forItemWithIdentifier: identifier)
                    } else {
                        // Nothing we can do here
                    }
                }
                
                completionHandler(nil)
            }
            
            return Progress()
        }
        
        if actionIdentifier == FileProviderItemActionsManager.MakeAvailableOnline {
            Task {
                for identifier in itemIdentifiers {
                    fileProviderItemActions.makeAvailableOnlineOnly(identifier: identifier)
                    if #available(macOSApplicationExtension 13.0, *) {
                        try await manager.requestModification(of: [.extendedAttributes], forItemWithIdentifier: identifier)
                    } else {
                        // Nothing we can do here
                    }
                }
                
                completionHandler(nil)
            }
            
            return Progress()
        }
        
        
        return Progress()
    }
    
}
