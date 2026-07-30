//
//  CreateFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 10/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import RealmSwift

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
          
            let inProgressId = ObjectId.generate()
            activityManager.saveActivityEntry(entry: ActivityEntry(_id: inProgressId, filename: item.filename, kind: .upload, status: .inProgress))
            
            do {
                var isPackage = FileProviderItem.isPackage(filename: item.filename)

                if !isPackage, let resourceValues = try? fileContent.resourceValues(forKeys: [.isPackageKey]) {
                    isPackage = resourceValues.isPackage == true
                }
                
                if isPackage {
                    self.logger.info("📦 Starting upload of package: \(item.filename)")
                    
                    var createdFolderId: String
                    var createdFolderUuid: String
                    
                    do {
                        let createdFolder = try await driveNewAPI.createFolderNew(
                            parentFolderUuid: parentUUID,
                            folderName: item.filename,
                            debug: true
                        )
                        createdFolderId = String(createdFolder.id)
                        createdFolderUuid = createdFolder.uuid
                        self.logger.info("📦 Created package folder on cloud \(item.filename)")
                    } catch {
                        if let apiClientError = error as? APIClientError, apiClientError.statusCode == 409 {
                            let existences = try await driveNewAPI.getFolderExistencesInFolder(folderParentUuid: parentUUID, folderName: item.filename)
                            if let folder = existences.existentFolders.first(where: {
                                $0.plainName == item.filename && $0.removed == false
                            }) {
                                createdFolderId = String(folder.id)
                                createdFolderUuid = folder.uuid
                            } else {
                                throw error
                            }
                        } else {
                            self.logger.error("📦 error uploading package  \(error.getErrorDescription())")
                            throw error
                        }
                    }
                    
                    try await uploadDirectoryIteratively(
                        localURL: fileContent,
                        parentFolderId: createdFolderId,
                        parentFolderUuid: createdFolderUuid
                    )
                    
                    let parentIdIsRootFolder = FileProviderItem.parentIdIsRootFolder(identifier: item.parentItemIdentifier)
                    let fileProviderItem = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: createdFolderId),
                        filename: item.filename,
                        parentId: parentIdIsRootFolder ? .rootContainer : item.parentItemIdentifier,
                        createdAt: Date(),
                        updatedAt: Date(),
                        itemExtension: (item.filename as NSString).pathExtension,
                        itemType: .file,
                        size: 0
                    )
                    completionHandler(fileProviderItem, [], false, nil)
                    activityManager.updateActivityEntryStatus(id: inProgressId, filename: item.filename, kind: .upload, status: .finished)
                    return
                }

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
                var uploadBucket: String = user.bucket
                
                if sizeInt > 0 {
                    let result = try await networkFacade.uploadFile(
                        input: inputStream,
                        encryptedOutput: encryptedFileDestination,
                        fileSize: sizeInt,
                        bucketId: uploadBucket,
                        progressHandler:{ completedProgress in
                            progress.completedUnitCount = Int64(completedProgress * 100)
                        }
                        ,debug: true
                    )
                    
                    uploadFileId = result.id
                    uploadSize = result.size
                    uploadBucket = result.bucket
                    
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
                        bucket: uploadBucket,
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
                self.logger.info("✅ Created file correctly with identifier \(fileProviderItem.itemIdentifier.rawValue) -  \(item.filename)")
                
                
                // Respond, then process the thumbnail so we don't block the UI
                let thumbnailUpload = await self.generateAndUploadThumbnail(
                    driveItemId: createdFile.id,
                    fileURL: self.fileContent,
                    destinationURL: self.thumbnailFileDestination,
                    encryptedThumbnailDestination: self.encryptedThumbnailFileDestination,
                    fileUuid: createdFile.uuid
                )
                
                completionHandler(fileProviderItem, [], false, nil )
                activityManager.updateActivityEntryStatus(id: inProgressId, filename: FileProviderItem.getFilename(name: createdFile.plain_name, itemExtension: createdFile.type), kind: .upload, status: .finished)

                
            } catch {
                error.reportToSentry()
                activityManager.updateActivityEntryStatus(id: inProgressId, filename: item.filename, kind: .upload, status: .failed)
                self.logger.error("❌ Failed to create file \(item.filename) : \(error.getErrorDescription())")
                completionHandler(nil, [], false, error.toFileProviderError())
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
            return nil
        }
        
    }
    
    private func uploadDirectoryIteratively(localURL: URL, parentFolderId: String, parentFolderUuid: String) async throws {
        struct FolderUploadTask {
            let localURL: URL
            let cloudFolderId: String
            let cloudFolderUuid: String
        }
        
        var queue: [FolderUploadTask] = [FolderUploadTask(
            localURL: localURL,
            cloudFolderId: parentFolderId,
            cloudFolderUuid: parentFolderUuid
        )]
        
        let fileManager = FileManager.default
        
        while !queue.isEmpty {
            let currentTask = queue.removeFirst()
            let contents = try fileManager.contentsOfDirectory(
                at: currentTask.localURL,
                includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey],
                options: []
            )
            
            for itemURL in contents {
                let name = itemURL.lastPathComponent
                let resourceValues = try itemURL.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .isSymbolicLinkKey])
                let isDirectory = resourceValues.isDirectory ?? false
                let isSymbolicLink = resourceValues.isSymbolicLink ?? false
                let fileSize = resourceValues.fileSize ?? 0
                
                if isSymbolicLink {
                    continue
                }
                
                if isDirectory {
                    let folderInfo = try await resolveOrCreateFolder(name: name, parentFolderUuid: currentTask.cloudFolderUuid)
                    
                    queue.append(FolderUploadTask(
                        localURL: itemURL,
                        cloudFolderId: folderInfo.id,
                        cloudFolderUuid: folderInfo.uuid
                    ))
                } else {
                    do {
                        try await uploadPackageFile(
                            localURL: itemURL,
                            filename: name,
                            fileSize: fileSize,
                            parentFolderId: currentTask.cloudFolderId,
                            parentFolderUuid: currentTask.cloudFolderUuid
                        )
                    } catch {
                        self.logger.error("❌ Failed to upload internal package file \(name): \(error.getErrorDescription())")
                    }
                }
            }
        }
    }
    
    private func resolveOrCreateFolder(name: String, parentFolderUuid: String) async throws -> (id: String, uuid: String) {
        do {
            let createdFolder = try await driveNewAPI.createFolderNew(
                parentFolderUuid: parentFolderUuid,
                folderName: name,
                debug: true
            )
            return (String(createdFolder.id), createdFolder.uuid)
        } catch {
            guard let apiClientError = error as? APIClientError, apiClientError.statusCode == 409 else {
                throw error
            }
            
            let existences = try await driveNewAPI.getFolderExistencesInFolder(folderParentUuid: parentFolderUuid, folderName: name)
            if let folder = existences.existentFolders.first(where: {
                $0.plainName == name && $0.removed == false
            }) {
                return (String(folder.id), folder.uuid)
            } else {
                throw error
            }
        }
    }
    
    private func fetchExistingFileUuid(filename: String, parentFolderUuid: String) async -> String? {
        let plainName = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        let existenceFile = ExistenceFile(plainName: plainName, type: ext)
        
        do {
            let checkResult = try await driveNewAPI.getExistenceFileInFolderByPlainName(
                uuid: parentFolderUuid,
                files: [existenceFile],
                debug: true
            )
            if let foundFile = checkResult.existentFiles.first(where: {
                $0.plainName == plainName && $0.type == ext
            }) {
                return foundFile.uuid
            }
        } catch {
            
        }
        return nil
    }
    
    private func uploadPackageFile(localURL: URL, filename: String, fileSize: Int, parentFolderId: String, parentFolderUuid: String) async throws {
        let plainName = (filename as NSString).deletingPathExtension
        let ext = (filename as NSString).pathExtension
        
      
        let existingFileUuid = await fetchExistingFileUuid(filename: filename, parentFolderUuid: parentFolderUuid)
        
        guard let inputStream = InputStream(url: localURL) else {
            throw UploadFileUseCaseError.CannotOpenInputStream
        }
        
        let encryptedFileDestination = fileContent.deletingLastPathComponent().appendingPathComponent("enc-package-\(UUID().uuidString).enc")
        
        defer {
            try? FileManager.default.removeItem(at: encryptedFileDestination)
        }
        
        var uploadFileId: String? = nil
        var uploadSize: Int = fileSize
        var uploadBucket: String = user.bucket
        
        if fileSize > 0 {
            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: encryptedFileDestination,
                fileSize: fileSize,
                bucketId: uploadBucket,
                progressHandler: { _ in },
                debug: true
            )
            uploadFileId = result.id
            uploadSize = result.size
            uploadBucket = result.bucket
        }
        
        if let fileUuid = existingFileUuid {
          
            _ = try await driveNewAPI.replaceFileId(fileUuid: fileUuid, newFileId: uploadFileId, newSize: uploadSize)
        } else {
      
            let encryptedFilename = try encrypt.encrypt(
                string: plainName,
                password: "\(config.CRYPTO_SECRET2)-\(parentFolderId)",
                salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
            )
            
            _ = try await driveNewAPI.createFileNew(createFile: CreateFileDataNew(
                    fileId: uploadFileId,
                    type: ext,
                    bucket: uploadBucket,
                    size: uploadSize,
                    folderId: 0,
                    name: encryptedFilename.base64EncodedString(),
                    plainName: plainName,
                    folderUuid: parentFolderUuid
                ),
                debug: true
            )
        }
    }
}

