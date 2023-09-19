//
//  CreateFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 10/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

enum CreateFileUseCaseError: Error {
    case InvalidParentId
    case CannotOpenInputStream
    case MissingDocumentSize
}


struct CreateFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "CreateFile")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let item: NSFileProviderItem
    private let encryptedFileDestination: URL
    private let encryptedThumbnailFileDestination: URL
    private let thumbnailFileDestination: URL
    private let fileContent: URL
    private let networkFacade: NetworkFacade
    private let completionHandler: (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
    private let driveAPI = APIFactory.Drive
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let activityManager: ActivityManager
    init(
        networkFacade: NetworkFacade,
        user: DriveUser,
        activityManager: ActivityManager,
        item: NSFileProviderItem,
        url: URL,
        encryptedFileDestination: URL,
        thumbnailFileDestination:URL,
        encryptedThumbnailFileDestination: URL,
        completionHandler: @escaping (NSFileProviderItem?, NSFileProviderItemFields, Bool, Error?) -> Void
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
    }
 
    public func run() -> Progress {
        self.logger.info("Creating file")
        let progress = Progress(totalUnitCount: 100)
        
        Task {
            do {
               
                guard let inputStream = InputStream(url: fileContent) else {
                    throw CreateFileUseCaseError.CannotOpenInputStream
                }
                
                guard let size = item.documentSize else {
                    throw CreateFileUseCaseError.MissingDocumentSize
                }
                
                guard let sizeInt = size?.intValue else {
                    throw CreateFileUseCaseError.MissingDocumentSize
                }
                
                
                let filename = (item.filename as NSString)
                self.logger.info("Starting upload for file \(filename)")
                self.logger.info("Parent id: \(item.parentItemIdentifier.rawValue)")
                
                /// Upload a file to the Internxt network and returns an id used later to create a file in Drive with that fileId
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
               
                let parentId = item.parentItemIdentifier == .rootContainer ? String(user.root_folder_id) : item.parentItemIdentifier.rawValue
                
                let encryptedFilename = try encrypt.encrypt(
                    string: filename.deletingPathExtension,
                    password: "\(config.CRYPTO_SECRET2)-\(parentId)",
                    salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                    iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
                )
                let parentIdIsRootFolder = FileProviderItem.parentIdIsRootFolder(identifier: item.parentItemIdentifier)
                
                let createdFile = try await driveAPI.createFile(createFile: CreateFileData(
                        fileId: result.id,
                        type: filename.pathExtension,
                        bucket: result.bucket,
                        size: result.size,
                        folderId: parentIdIsRootFolder ? user.root_folder_id : Int(item.parentItemIdentifier.rawValue)!,
                        name: encryptedFilename.base64EncodedString(),
                        plainName: filename.deletingPathExtension
                    )
                )
                
                
                let fileProviderItem = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFile.uuid)),
                    filename: item.filename,
                    parentId: parentIdIsRootFolder ? .rootContainer : item.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(createdFile.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(createdFile.updatedAt) ?? Date(),
                    itemExtension: createdFile.type,
                    itemType: .file,
                    size: result.size
                )
                
                completionHandler(fileProviderItem, [], false, nil )
                activityManager.saveActivityEntry(entry: ActivityEntry(filename: FileProviderItem.getFilename(name: createdFile.plain_name ?? createdFile.name, itemExtension: createdFile.type), kind: .upload, status: .finished))
                self.logger.info("✅ Created file correctly with identifier \(fileProviderItem.itemIdentifier.rawValue)")
                
                self.logger.info("🖼️ Processing thumbnail...")
                
                // Respond, then process the thumbnail so we don't block the UI
                let thumbnailUpload = await self.generateAndUploadThumbnail(
                    driveItemId: createdFile.id,
                    fileURL: self.fileContent,
                    destinationURL: self.thumbnailFileDestination,
                    encryptedThumbnailDestination: self.encryptedThumbnailFileDestination
                )
                
                if let thumbnailUploadUnwrapped = thumbnailUpload {
                    self.logger.info("✅ Thumbnail uploaded with fileId \(thumbnailUploadUnwrapped.fileId)...")
                } else {
                    self.logger.info("❌ Thumbnail uploaded failed")
                }
                
                
                
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to create file: \(error.localizedDescription)")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return progress
    }
    
    func generateAndUploadThumbnail(driveItemId: Int, fileURL: URL, destinationURL: URL, encryptedThumbnailDestination: URL) async -> CreateThumbnailResponse? {
        do {
            let thumbnailGenerationResult = try await ThumbnailGenerator.shared.generateThumbnail(
                for: fileURL,
                destinationURL: destinationURL
            )
            
            let size = thumbnailGenerationResult.url.fileSize
            
            guard let inputStream = InputStream(url: thumbnailGenerationResult.url) else {
                throw CreateFileUseCaseError.CannotOpenInputStream
            }
            
            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: encryptedThumbnailDestination,
                fileSize: Int(size),
                bucketId: user.bucket,
                progressHandler:{progress in
                    print("Thumbnail progress: ", progress)
                }
            )
            var fileExtension: String = ""
            if #available(macOSApplicationExtension 13.0, *) {
                fileExtension = NSString(string: thumbnailGenerationResult.url.path()).pathExtension
            } else {
                fileExtension = NSString(string: thumbnailGenerationResult.url.path).pathExtension
            }
            
            
            let createdThumbnail = try await driveAPI.createThumbnail(createThumbnail: CreateThumbnailData(
                bucketFile: result.id,
                bucketId: result.bucket,
                fileId: driveItemId,
                height: thumbnailGenerationResult.height,
                width: thumbnailGenerationResult.width,
                size: Int64(size),
                type: fileExtension)
            )
            
            return createdThumbnail
                                 
        } catch {
            // If the thumbnail generation fails, don't block the upload
            // just report it, and keep processing the upload
            error.reportToSentry()
            return nil
        }
        
    }
}
