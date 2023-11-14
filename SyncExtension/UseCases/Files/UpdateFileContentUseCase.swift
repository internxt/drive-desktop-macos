//
//  UpdateFileContentUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 14/11/23.
//


import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

enum UpdateFileContentUseCaseError: Error {
    case InvalidParentId
    case CannotOpenInputStream
    case MissingDocumentSize
}


struct UpdateFileContentUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "UpdateFileContent")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let item: NSFileProviderItem
    private let encryptedFileDestination: URL
    private let fileContent: URL
    private let networkFacade: NetworkFacade
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let driveAPI = APIFactory.Drive
    private let driveNewAPI = APIFactory.DriveNew
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let trackId = UUID().uuidString
    init(
        networkFacade: NetworkFacade,
        user: DriveUser,
        item: NSFileProviderItem,
        url: URL,
        encryptedFileDestination: URL,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    ) {
        self.item = item
        self.fileContent = url
        self.encryptedFileDestination = encryptedFileDestination
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
    }
    
   
    
    private func trackStart(processIdentifier: String) -> Date {
        let filename = (item.filename as NSString)
        let event = UploadStartedEvent(
            fileName: filename.deletingPathExtension,
            fileExtension: filename.pathExtension,
            fileSize: item.documentSize as! Int64,
            fileUploadId: item.itemIdentifier.rawValue,
            processIdentifier: processIdentifier,
            parentFolderId: Int(getParentId()) ?? -1
        )
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
        
        
        return Date()
    }
    
    private func trackEnd(processIdentifier: String, startedAt: Date) {
        let filename = (item.filename as NSString)
        let event = UploadCompletedEvent(
            fileName: filename.deletingPathExtension,
            fileExtension: filename.pathExtension,
            fileSize: item.documentSize as! Int64,
            fileUploadId: item.itemIdentifier.rawValue,
            processIdentifier: processIdentifier,
            parentFolderId: Int(getParentId()) ?? -1,
            elapsedTimeMs: Date().timeIntervalSince(startedAt) * 1000
        )
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }
    
    private func trackError(processIdentifier: String, error: any Error) {
        let filename = (item.filename as NSString)
        let event = UploadErrorEvent(
            fileName: filename.deletingPathExtension,
            fileExtension: filename.pathExtension,
            fileSize: item.documentSize as! Int64,
            fileUploadId: item.itemIdentifier.rawValue,
            processIdentifier: processIdentifier,
            parentFolderId: Int(getParentId()) ?? -1,
            error: error
        )
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }
    
    
    private func getParentId() -> String {
        return item.parentItemIdentifier == .rootContainer ? String(user.root_folder_id) : item.parentItemIdentifier.rawValue
    }
    public func run() -> Progress {
        self.logger.info("Updating file")
        let progress = Progress(totalUnitCount: 100)
        let startedAt = self.trackStart(processIdentifier: trackId)
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
                
                let result = try await networkFacade.uploadFile(
                    input: inputStream,
                    encryptedOutput: encryptedFileDestination,
                    fileSize: sizeInt,
                    bucketId: user.bucket,
                    progressHandler:{ completedProgress in
                        progress.completedUnitCount = Int64(completedProgress * 100)
                    }
                )
                
                self.logger.info("Upload completed with id \(result.id)")
               
                let parentIdIsRootFolder = FileProviderItem.parentIdIsRootFolder(identifier: item.parentItemIdentifier)
                
                
                let existingFile = try await driveNewAPI.getFileMetaByUuid(uuid: item.itemIdentifier.rawValue)
                                
                _ = try await driveNewAPI.replaceFileId(fileUuid: existingFile.uuid, newFileId: result.id, newSize: result.size)
                
                let fileProviderItem = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(existingFile.uuid)),
                    filename: item.filename,
                    parentId: parentIdIsRootFolder ? .rootContainer : item.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(existingFile.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(existingFile.updatedAt) ?? Date(),
                    itemExtension: existingFile.type,
                    itemType: .file,
                    size: result.size
                )
                
                self.trackEnd(processIdentifier: trackId, startedAt: startedAt)
                
                completionHandler(fileProviderItem, [], false, nil )
                
                self.logger.info("✅ Updated file content correctly with identifier \(fileProviderItem.itemIdentifier.rawValue)")
                
                
                
            } catch {
                self.trackError(processIdentifier: trackId, error: error)
                error.reportToSentry()
                self.logger.error("❌ Failed to update file content: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return progress
    }
}

