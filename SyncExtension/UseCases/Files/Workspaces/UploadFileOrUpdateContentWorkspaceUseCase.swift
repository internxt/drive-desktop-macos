//
//  UploadFileOrUpdateContentWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 8/11/24.
//

import Foundation
import InternxtSwiftCore
import FileProvider

struct UploadFileOrUpdateContentWorkspaceUseCase {
    let logger = syncExtensionLogger
    
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let item: NSFileProviderItem
    private let encryptedFileDestination: URL
    private let encryptedThumbnailFileDestination: URL
    private let thumbnailFileDestination: URL
    private let fileContent: URL
    private let networkFacade: NetworkFacade
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let driveNewAPI = APIFactory.DriveNew
    private let user: DriveUser
    private let activityManager: ActivityManager
    let workspace: [AvailableWorkspace]

    init(
        networkFacade: NetworkFacade,
        user: DriveUser,
        activityManager: ActivityManager,
        item: NSFileProviderItem,
        url: URL,
        encryptedFileDestination: URL,
        thumbnailFileDestination:URL,
        encryptedThumbnailFileDestination: URL,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void,
        workspace: [AvailableWorkspace]
    ) {
        self.item = item
        self.activityManager = activityManager
        self.fileContent = url
        self.encryptedFileDestination = encryptedFileDestination
        self.encryptedThumbnailFileDestination = encryptedThumbnailFileDestination
        self.thumbnailFileDestination = thumbnailFileDestination
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
        self.workspace = workspace
    }
    
    private func fileAlreadyExistsByName() async -> GetFileInFolderByPlainNameResponse? {
        do {
            guard let folderIdInt = Int(getParentId(item: self.item, user: self.user)) else {
                return nil
            }
            
            let filename = (item.filename as NSString)
            return try await self.driveNewAPI.getFileInFolderByPlainName(folderId: folderIdInt, plainName: filename.deletingPathExtension, type:filename.pathExtension)
            
        } catch {
            return nil
        }
        
    }
    
    func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        Task {
            self.logger.info("Checking if file already exists...")
       //     guard let fileByName = await self.fileAlreadyExistsByName() else {
                self.logger.info("File doesn't exists in this folder, uploading")
                return UploadFileWorkspaceUseCase(
                    networkFacade: self.networkFacade,
                    user: self.user,
                    activityManager: self.activityManager,
                    item: self.item,
                    url: self.fileContent,
                    encryptedFileDestination: self.encryptedFileDestination,
                    thumbnailFileDestination: self.thumbnailFileDestination,
                    encryptedThumbnailFileDestination: self.encryptedThumbnailFileDestination,
                    completionHandler: self.completionHandler,
                    progress: progress, workspace: self.workspace
                ).run()
      //      }
            
            
//            self.logger.info("File already exists in this folder, replacing content")
//            
//            
//            return UpdateFileContentUseCase(
//                networkFacade: self.networkFacade,
//                user: self.user,
//                item: self.item,
//                fileUuid: fileByName.uuid,
//                url: self.fileContent,
//                encryptedFileDestination: self.encryptedFileDestination,
//                completionHandler: self.completionHandler,
//                progress: progress
//            ).run()
            
        }
        
        return progress
    }
}

