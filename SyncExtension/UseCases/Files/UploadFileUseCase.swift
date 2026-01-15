//
//  CreateFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 10/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

enum UploadFileUseCaseError: Error {
    case InvalidParentId
    case CannotOpenInputStream
    case MissingDocumentSize
    case InvalidParentUUID
}


struct UploadFileUseCase {
    let logger = syncExtensionLogger
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
    private let driveNewAPI = APIFactory.DriveNew
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let activityManager: ActivityManager
    private let trackId = UUID().uuidString
    private let progress: Progress
    private let parentUUID: String
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
        progress: Progress,
        parentUuid: String
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
        self.progress = progress
        self.parentUUID = parentUuid
    }
    
   
    
    private func trackStart(processIdentifier: String) -> Date {
        return Date()
    }
    
    private func trackEnd(processIdentifier: String, startedAt: Date) -> TimeInterval {
        let elapsedTime = Date().timeIntervalSince(startedAt)
        return elapsedTime
    }
    
   
    
    private func getParentId() -> String {
        return item.parentItemIdentifier == .rootContainer ? String(user.root_folder_id) : item.parentItemIdentifier.rawValue
    }
    public func run() -> Progress {
        self.logger.info("Creating file")
        
        Task {
            do {
                let parentIdIsRootFolder = FileProviderItem.parentIdIsRootFolder(identifier: item.parentItemIdentifier)

                let startedAt = self.trackStart(processIdentifier: trackId)
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
                self.logger.info("Parent id: \(getParentId())")
                
                var uploadFileId: String? = nil
                var uploadSize: Int = sizeInt
                
                if sizeInt > 0 {
                    let result = try await networkFacade.uploadFile(
                        input: inputStream,
                        encryptedOutput: encryptedFileDestination,
                        fileSize: sizeInt,
                        bucketId: user.bucket,
                        progressHandler:{ completedProgress in
                            progress.completedUnitCount = Int64(completedProgress * 100)
                        }
                        ,debug: true
                    )
                    
                    uploadFileId = result.id
                    uploadSize = result.size
                    
                    self.logger.info("Upload completed with id \(result.id)")
                } else {
                    self.logger.info("⚠️ Skipping network upload for empty file: \(filename)")
                    progress.completedUnitCount = 100
                }
               
                let encryptedFilename = try encrypt.encrypt(
                    string: filename.deletingPathExtension,
                    password: "\(config.CRYPTO_SECRET2)-\(self.getParentId())",
                    salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                    iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
                )
                let createdFile = try await driveNewAPI.createFileNew(createFile: CreateFileDataNew(
                        fileId: uploadFileId,
                        type: filename.pathExtension,
                        bucket: user.bucket,
                        size: uploadSize,
                        folderId: 0,
                        name: encryptedFilename.base64EncodedString(),
                        plainName: filename.deletingPathExtension,
                        folderUuid: parentUUID
                        
                    ),
                debug: true
                )
                
                
                let fileProviderItem = FileProviderItem(
                    identifier: NSFileProviderItemIdentifier(rawValue: String(createdFile.uuid)),
                    filename: item.filename,
                    parentId: parentIdIsRootFolder ? .rootContainer : item.parentItemIdentifier,
                    createdAt: Time.dateFromISOString(createdFile.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(createdFile.updatedAt) ?? Date(),
                    itemExtension: createdFile.type,
                    itemType: .file,
                    size: uploadSize
                )
                
                let uploadDuration = self.trackEnd(processIdentifier: trackId, startedAt: startedAt)
                
                self.logger.info("⏱️ Upload completed in \(uploadDuration) seconds")
                self.logger.info("✅ Created file correctly with identifier \(fileProviderItem.itemIdentifier.rawValue)")
                
                self.logger.info("🖼️ Processing thumbnail...")
                
                // Respond, then process the thumbnail so we don't block the UI
                let thumbnailUpload = await self.generateAndUploadThumbnail(
                    driveItemId: createdFile.id,
                    fileURL: self.fileContent,
                    destinationURL: self.thumbnailFileDestination,
                    encryptedThumbnailDestination: self.encryptedThumbnailFileDestination,
                    fileUuid: createdFile.uuid
                )
                
                if let thumbnailUploadUnwrapped = thumbnailUpload {
                    self.logger.info("✅ Thumbnail uploaded with fileId \(thumbnailUploadUnwrapped.fileId)...")
                } else {
                    self.logger.info("❌ Thumbnail uploaded failed")
                }
                
                completionHandler(fileProviderItem, [], false, nil )
                activityManager.saveActivityEntry(entry: ActivityEntry(filename: FileProviderItem.getFilename(name: createdFile.plain_name ?? createdFile.name, itemExtension: createdFile.type), kind: .upload, status: .finished))
                
            } catch {
                error.reportToSentry()

                self.logger.error("❌ Failed to create file: \(error.getErrorDescription())")
                completionHandler(nil, [], false, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return progress
    }
    
    func patchFileContent() -> Void {
        
    }
    
    func generateAndUploadThumbnail(driveItemId: Int, fileURL: URL, destinationURL: URL, encryptedThumbnailDestination: URL, fileUuid: String) async -> CreateThumbnailResponse? {
        do {
            let thumbnailGenerationResult = try await ThumbnailGenerator.shared.generateThumbnail(
                for: fileURL,
                destinationURL: destinationURL
            )
            
            let size = thumbnailGenerationResult.url.fileSize
            
            guard let inputStream = InputStream(url: thumbnailGenerationResult.url) else {
                throw UploadFileUseCaseError.CannotOpenInputStream
            }
            
            let uploadFileResult = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: encryptedThumbnailDestination,
                fileSize: Int(size),
                bucketId: user.bucket,
                progressHandler:{progress in
                }
            )
            var fileExtension: String = ""
            if #available(macOSApplicationExtension 13.0, *) {
                fileExtension = NSString(string: thumbnailGenerationResult.url.path()).pathExtension
            } else {
                fileExtension = NSString(string: thumbnailGenerationResult.url.path).pathExtension
            }
            
            
            let createdThumbnail = try await driveNewAPI.createThumbnail(createThumbnail: CreateThumbnailData(
                bucketFile: uploadFileResult.id,
                bucketId: uploadFileResult.bucket,
                height: thumbnailGenerationResult.height,
                width: thumbnailGenerationResult.width,
                size: Int64(size),
                type: fileExtension,
                fileUuid: fileUuid)
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

