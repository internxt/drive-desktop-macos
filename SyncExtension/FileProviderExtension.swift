//
//  FileProviderExtension.swift
//  SyncExtension
//
//  Created by Robert Garcia on 30/7/23.
//

import FileProvider
import InternxtSwiftCore
import Combine
import Foundation
import AppKit
import PushKit

enum CreateItemError: Error {
    case NoParentIdFound
}



let logger = syncExtensionLogger
class FileProviderExtension: NSObject, NSFileProviderReplicatedExtension, NSFileProviderCustomAction , PKPushRegistryDelegate{
 
    let fileProviderItemActions = FileProviderItemActionsManager()
    let config = ConfigLoader()
    let manager: NSFileProviderManager
    let tmpURL: URL
    let networkFacade: NetworkFacade
    let user: DriveUser
    let mnemonic: String
    let authManager: AuthManager
    let activityManager: ActivityManager
    let realtime: RealtimeService?
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let DEVICE_TYPE = "macos"
    var pushRegistry: PKPushRegistry!
    private let AUTH_TOKEN_KEY = "AuthToken"
    
    required init(domain: NSFileProviderDomain) {
        
        
        logger.info("Starting sync extension with version \(Bundle.version())")
        ErrorUtils.start()
        
        self.activityManager = ActivityManager()
        guard let manager = NSFileProviderManager(for: domain) else {
            ErrorUtils.fatal("Cannot get FileProviderManager for domain")
        }
        

        self.manager = manager
        
        let authManager = AuthManager()
        self.authManager = authManager
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
            logger.info("TMP directory at \(self.tmpURL)")
        } catch {
            ErrorUtils.fatal("Cannot get tmp directory URL, file provider cannot work")
        }
        
        logger.info("Created extension with domain \(domain.displayName)")
        let config = authManager.config
        if let authToken = config.getAuthToken() {
            self.realtime = RealtimeService.init(
                token: authToken,
                onConnect: {},
                onDisconnect: {},
                onEvent: {
                    Task {try? await manager.signalEnumerator(for: .workingSet)}
                }
            )
        } else {
            self.realtime = nil
        }
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
        
        pushRegistry = PKPushRegistry(queue: nil)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.fileProvider]
        self.refreshAuthTokensIfNeeded()
    }
    

    func cleanTmpDirectory() throws {
        let files = try FileManager.default.contentsOfDirectory(at: tmpURL, includingPropertiesForKeys: nil)
        
        try files.forEach{fileUrl in
            try FileManager.default.removeItem(at: fileUrl)
        }
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
    
    func refreshAuthTokensIfNeeded() -> Void {
        Task {
            do {
                let refreshTokenCheckResult = try authManager.needRefreshToken()
                logger.info("Auth token: Created at \(refreshTokenCheckResult.authTokenCreationDate), days until expiration: \(refreshTokenCheckResult.authTokenDaysUntilExpiration)")
                
                logger.info("Legacy auth token: Created at \(refreshTokenCheckResult.legacyAuthTokenCreationDate), days until expiration: \(refreshTokenCheckResult.legacyAuthTokenDaysUntilExpiration)")
                
                
                if refreshTokenCheckResult.needsRefresh {
                    try await authManager.refreshTokens()
                    logger.info("Auth tokens refreshed successfully")
                } else {
                    logger.info("Auth tokens doesn't need a refresh")
                    
                }
            } catch {
                logger.error(["Cannot refresh tokens, something went wrong", error])
                error.reportToSentry()
            }
            
        }
        
    }
    
    func item(for identifier: NSFileProviderItemIdentifier, request: NSFileProviderRequest, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) -> Progress {
        refreshAuthTokensIfNeeded()
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
        refreshAuthTokensIfNeeded()
        let encryptedFileDestinationURL = makeTemporaryURL("encrypt", "enc")
        let destinationURL = makeTemporaryURL("plain")
        
        func internalCompletionHandler(url: URL?, item: NSFileProviderItem?, error: Error?) -> Void {
            
            completionHandler(url, item, error)
            do {
                try FileManager.default.removeItem(at: encryptedFileDestinationURL)
            } catch {
                logger.error("Failed to cleanup TMP files for item \(itemIdentifier.rawValue)")
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
        refreshAuthTokensIfNeeded()
        // This is a Microsoft Office tmp file, we don't want to sync this
        if(itemTemplate.filename.hasPrefix("~$")) {
            logger.info("⚠️ Microsoft Office tmp file detected with name: \(itemTemplate.filename)")
            completionHandler(itemTemplate, [], false, nil)
            return Progress()
        }
        
        logger.info("Creating file with name \(itemTemplate.filename)")
        
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
                
                try? FileManager.default.removeItem(at: fileCopy)
                try? FileManager.default.removeItem(at: encryptedFileDestination)
                try? FileManager.default.removeItem(at: encryptedThumbnailFileDestination)
                try? FileManager.default.removeItem(at: thumbnailFileDestination)
                
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
        
        refreshAuthTokensIfNeeded()
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
            logger.info("File last use date has changed, let it pass")
            completionHandler(item, [], false, nil)
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
        refreshAuthTokensIfNeeded()
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
        
        if actionIdentifier == FileProviderItemActionsManager.OpenWebBrowser {
            Task {
                for identifier in itemIdentifiers {
                    do {
                        let item = try await driveNewAPI.getFolderOrFileMetaById(id: identifier.rawValue)
                        if let uuid = item.uuid {
                            generateDriveWebURL(isFile: !item.isFolder, uuid: uuid).open()
                        }

                    } catch {
                        completionHandler(error)
                    }
                }
                completionHandler(nil)
            }
            
            return Progress()
        }
        
        return Progress()
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ){
        refreshAuthTokensIfNeeded()
        logger.info("📍 Got Device token for push notifications from SyncExtension")
        let deviceToken = credentials.token
        
        
        guard let newAuthToken = config.getAuthToken() else{
            logger.error("Cannot get AuthToken")
            return
        }
        let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        Task {
            do {
                _ = try await driveNewAPI.registerPushDeviceToken(currentAuthToken: newAuthToken, deviceToken: deviceTokenString, type: DEVICE_TYPE)
            }catch{
                logger.error(["Cannot sync token", error])
            }
        }
    }

            
}
