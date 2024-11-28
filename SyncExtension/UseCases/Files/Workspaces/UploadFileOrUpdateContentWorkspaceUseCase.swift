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
    private let driveNewAPI = APIFactory.DriveWorkspace
    private let user: DriveUser
    private let activityManager: ActivityManager
    private let workspace: [AvailableWorkspace]
    private let workspaceCredentials: WorkspaceCredentialsResponse
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
        workspace: [AvailableWorkspace],
        workspaceCredentials: WorkspaceCredentialsResponse
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
        self.workspaceCredentials = workspaceCredentials
    }
    
    private func fileAlreadyExistsByName() async -> GetExistenceFileInFolderResponse? {
        do {
            guard !workspace.isEmpty else {
                self.logger.error("Workspace array is empty, cannot proceed with item access.")
                return nil
            }
            
            var parentFolderUuid = item.parentItemIdentifier.rawValue
            
            if item.parentItemIdentifier == .rootContainer {
                parentFolderUuid =  workspace[0].workspaceUser.rootFolderId
            }

            
            let filename = (item.filename as NSString)
            let existenceFile = ExistenceFile(plainName: filename.deletingPathExtension, type: filename.pathExtension)
            let result = try await self.driveNewAPI.getExistenceFileInFolderByPlainName(uuid: parentFolderUuid, files: [existenceFile],debug: true)
            return result.existentFiles.isEmpty ? nil : result.existentFiles.first
            
        } catch {
            self.logger.error("Error in file already exists \(error.getErrorDescription())")
            return nil
        }
        
    }
    
    func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        Task {
            self.logger.info("Checking if file already exists...")
            guard let fileByName = await self.fileAlreadyExistsByName() else {
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
                    progress: progress, workspace: self.workspace, workspaceCredentials: workspaceCredentials
                ).run()
            }
            
            
            self.logger.info("File already exists in this folder, replacing content")
            
            
            return UpdateFileContentWorkspaceUseCase(
                networkFacade: self.networkFacade,
                user: self.user,
                item: self.item,
                fileUuid: fileByName.uuid,
                url: self.fileContent,
                encryptedFileDestination: self.encryptedFileDestination,
                completionHandler: self.completionHandler,
                progress: progress, workspaceCredentials: workspaceCredentials
            ).run()
            
        }
        
        return progress
    }
}

