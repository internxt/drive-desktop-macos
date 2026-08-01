//
//  PackageUploadService.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 31/7/26.
//

import Foundation
import InternxtSwiftCore

struct PackageUploadService {
    let networkFacade: NetworkFacade
    let user: DriveUser
    let encryptedFileDestination: URL
    
    private let logger = syncExtensionLogger
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let driveNewAPI = APIFactory.DriveNew
    private let config = ConfigLoader().get()
    
    func uploadDirectoryIteratively(localURL: URL, parentFolderId: String, parentFolderUuid: String) async throws {
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
        
        let tempEncryptedDestination = self.encryptedFileDestination.deletingLastPathComponent().appendingPathComponent("enc-package-\(UUID().uuidString).enc")
        
        defer {
            try? FileManager.default.removeItem(at: tempEncryptedDestination)
        }
        
        var uploadFileId: String? = nil
        var uploadSize: Int = fileSize
        var uploadBucket: String = user.bucket
        
        if fileSize > 0 {
            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: tempEncryptedDestination,
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
