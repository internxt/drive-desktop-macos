//
//  UpdateFileContentWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 8/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore

struct UpdateFileContentWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let item: NSFileProviderItem
    private let encryptedFileDestination: URL
    private let fileContent: URL
    private let networkFacade: NetworkFacade
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let driveNewAPI = APIFactory.DriveWorkspace
    private let user: DriveUser
    private let progress: Progress
    private let fileUuid: String
    private let workspaceCredentials: WorkspaceCredentialsResponse
    init(
        networkFacade: NetworkFacade,
        user: DriveUser,
        item: NSFileProviderItem,
        fileUuid: String,
        url: URL,
        encryptedFileDestination: URL,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void,
        progress: Progress,
        workspaceCredentials: WorkspaceCredentialsResponse
    ) {
        self.item = item
        self.fileContent = url
        self.encryptedFileDestination = encryptedFileDestination
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
        self.progress = progress
        self.fileUuid = fileUuid
        self.workspaceCredentials = workspaceCredentials
    }

    public func run() -> Progress {
        self.logger.info("Updating file")
        Task {
            do {
               
                guard let inputStream = InputStream(url: fileContent) else {
                    throw UploadFileUseCaseError.CannotOpenInputStream
                }
                
                guard let size = item.documentSize else {
                    throw UploadFileUseCaseError.MissingDocumentSize
                }
                
                guard let sizeInt = size?.intValue else {
                    throw UploadFileUseCaseError.MissingDocumentSize
                }
                
                
                let filename = (item.filename as NSString)
                self.logger.info("Starting upload for file \(filename)")
                self.logger.info("Parent id: \(item.parentItemIdentifier.rawValue)")
                
                var uploadFileId: String? = nil
                var uploadSize: Int = sizeInt
                
                if sizeInt > 0 {
                    let result = try await networkFacade.uploadFile(
                        input: inputStream,
                        encryptedOutput: encryptedFileDestination,
                        fileSize: sizeInt,
                        bucketId: workspaceCredentials.bucket,
                        progressHandler:{ completedProgress in
                            progress.completedUnitCount = Int64(completedProgress * 100)
                        }
                    )
                    
                    uploadFileId = result.id
                    uploadSize = result.size
                    
                    self.logger.info("Upload completed with id \(result.id)")
                } else {
                    self.logger.info("⚠️ Skipping network upload for empty file: \(filename)")
                    progress.completedUnitCount = 100
                }
               
                let parentIdIsRootFolder = FileProviderItem.parentIdIsRootFolder(identifier: item.parentItemIdentifier)
                
                
                self.logger.info("Getting file meta with UUID: \(self.fileUuid)")
                let existingFile = try await driveNewAPI.getFileMetaByUuid(uuid: fileUuid)
                            
                
                _ = try await driveNewAPI.replaceFileId(fileUuid: existingFile.uuid, newFileId: uploadFileId, newSize: uploadSize)
                
                let fileProviderItem = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(existingFile.uuid)),
                    filename: item.filename,
                    parentId: parentIdIsRootFolder ? .rootContainer : item.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(existingFile.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(existingFile.updatedAt) ?? Date(),
                    itemExtension: existingFile.type,
                    itemType: .file,
                    size: uploadSize
                )
                                
                completionHandler(fileProviderItem, [], false, nil )
                
                self.logger.info("✅ Updated file content correctly with identifier \(fileUuid)")
                
                
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to update file content: \(error.getErrorDescription())")
                
                if let apiClientError = error as? APIClientError, apiClientError.statusCode == 402 {
                    self.logger.error("❌ Cannot synchronize file due to payment/quota issue (402)")
                    completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue))
                } else {
                    completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
                }
            }
        }
        
        return progress
    }
}


