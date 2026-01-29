//
//  BakupUploadService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/15/24.
//

import SwiftUI
import RealmSwift
import FileProvider
import InternxtSwiftCore

enum BackupUploadError: Error {
    case CannotOpenInputStream
    case MissingDocumentSize
    case MissingParentFolder
    case MissingRemoteId
    case MissingURL
    case CannotCreateRealm
    case CannotCreateEncryptedContentURL
    case CannotAddNodeToRealm
    case CannotEditNodeToRealm
    case CannotFindNodeToRealm
    case CannotFindNodeInServer
    case BackupStoppedManually
}

enum BackupDownloadError: Error {
    case missingDeviceUuid
}

protocol BackupUploadServiceProtocol {
    func doSync(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error>
    func stopSync()
}

class BackupUploadService:  BackupUploadServiceProtocol, ObservableObject {
    private let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "App")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let config = ConfigLoader().get()
    private let networkFacade: NetworkFacade
    private let networkQueue = OperationQueue()
    private let completionQueue = OperationQueue()
    private let encryptedContentDirectory: URL
    private let retriesCount = 3
    private let deviceId: Int
    private let deviceUuid: String
    private let bucketId: String
    private let newAuthToken: String
    @Published var canDoBackup = true
    private let maxParentIdRetries = 3
    private let parentIdRetryDelayNs: UInt64 = 100_000_000

    init(networkFacade: NetworkFacade, encryptedContentDirectory: URL, deviceId: Int, bucketId: String,newAuthToken: String, deviceUuid: String) {
        self.networkFacade = networkFacade
        self.encryptedContentDirectory = encryptedContentDirectory
        self.deviceId = deviceId
        self.bucketId = bucketId
        self.newAuthToken = newAuthToken
        self.deviceUuid = deviceUuid
    }


    private var backupNewAPI: BackupAPI {
        return BackupAPI(baseUrl: config.DRIVE_NEW_API_URL, authToken: newAuthToken, clientName: CLIENT_NAME, clientVersion: getVersion())
    }

    

    private func getEncryptedContentURL(node: BackupTreeNode) -> URL? {
        let url = encryptedContentDirectory.appendingPathComponent(node.id)

        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            return nil
        }

        FileManager.default.createFile(atPath: url.absoluteString, contents: nil)

        return url
    }

    func doSync(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error> {
        if !canDoBackup {
            node.removeChildNodes()
            return .failure(BackupUploadError.BackupStoppedManually)
        }

        if (node.type == .folder) {
            return await self.syncNodeFolder(node: node)
        }
        return await self.syncNodeFile(node: node)
    }

    func stopSync() {
        DispatchQueue.main.async {
            self.canDoBackup = false
        }
    }
    
// MARK: - Thread-Safe  Operations
   
    private func addSyncedNodeSafely(_ node: SyncedNode) async throws {
        try await SyncedNodeRepository.shared.addSyncedNodeAsync(node)
    }
    
    private func editSyncedNodeDateSafely(remoteUuid: String, date: Date) async throws {
        try await SyncedNodeRepository.shared.editSyncedNodeDateAsync(remoteUuid: remoteUuid, date: date)
    }
    

    /// This handles race conditions where child operations start before parent has set remoteParentId.
    private func waitForParentInfo(node: BackupTreeNode) async -> (remoteParentId: Int, remoteParentUuid: String)? {
        for attempt in 0..<maxParentIdRetries {
            let parentInfo = node.getRemoteParentInfo()
            
            if let remoteParentId = parentInfo.remoteParentId,
               let remoteParentUuid = parentInfo.remoteParentUuid {
                if attempt > 0 {
                    self.logger.info("Got parent info for \(node.name) after \(attempt) retries")
                }
                return (remoteParentId, remoteParentUuid)
            }
            
            if attempt < maxParentIdRetries - 1 {
                self.logger.info("Waiting for parent info for \(node.name), attempt \(attempt + 1)/\(maxParentIdRetries)")
                try? await Task.sleep(nanoseconds: parentIdRetryDelayNs)
            }
        }
        
        return nil
    }

    private func syncNodeFolder(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error> {
        self.logger.info("Creating folder")

        guard let nodeURL = node.url else {
            return .failure(BackupUploadError.MissingURL)
        }

        var remoteParentId: Int? = nil
        var remoteParentUuid: String? = nil
        let foldername = node.name
        self.logger.info("Going to create folder \(foldername)")

        if let _ = node.parentId {
            guard let parentInfo = await waitForParentInfo(node: node) else {
                self.logger.info("Missing Parent Folder id \(foldername) after \(maxParentIdRetries) retries")
                return .failure(BackupUploadError.MissingParentFolder)
            }
            
            remoteParentId = parentInfo.remoteParentId
            remoteParentUuid = parentInfo.remoteParentUuid
        } else {
            remoteParentId = self.deviceId
            remoteParentUuid = self.deviceUuid
        }

        guard let safeRemoteParentId = remoteParentId else {
            self.logger.info("Missing Parent Folder id \(foldername) ")
            return .failure(BackupUploadError.MissingParentFolder)
        }
        
        guard let safeRemoteParentUuid = remoteParentUuid else {
            self.logger.info("Missing parent folder uuid \(foldername)")
            return .failure(BackupUploadError.MissingParentFolder)
        }

        self.logger.info("Parent id \(safeRemoteParentId)")

        do {
            let createdFolder = try await backupNewAPI.createBackupFolder(
                parentFolderUuid: safeRemoteParentUuid,
                folderName: foldername
            )

            self.logger.info("✅ Folder created successfully: \(createdFolder.id)")

            try await addSyncedNodeSafely(
                SyncedNode(
                    remoteId: createdFolder.id,
                    deviceId: node.deviceId,
                    remoteUuid: createdFolder.uuid,
                    url: nodeURL,
                    rootBackupFolder: node.rootBackupFolder,
                    parentId: node.parentId,
                    remoteParentId: safeRemoteParentId
                )
            )

            return .success(BackupTreeNodeSyncResult(id: createdFolder.id, uuid: createdFolder.uuid))
        } catch {
            self.logger.error("❌ Failed to create folder: \(error.getErrorDescription())")


            if let apiClientError = error as? APIClientError, apiClientError.statusCode == 409 {
                // Handle duplicated folder error
                do {
                    let parentChilds = try await backupNewAPI.getBackupChilds(folderUuid: "\(safeRemoteParentUuid)")

                    let folder = parentChilds.folders.first { currentFolder in
                        currentFolder.plainName == foldername && currentFolder.removed == false
                    }

                    guard let folder = folder else {
                        return .failure(BackupUploadError.CannotFindNodeInServer)
                    }

                    try await addSyncedNodeSafely(
                        SyncedNode(
                            remoteId: folder.id,
                            deviceId: node.deviceId,
                            remoteUuid: folder.uuid ?? "",
                            url: nodeURL,
                            rootBackupFolder: node.rootBackupFolder,
                            parentId: node.parentId,
                            remoteParentId: safeRemoteParentId
                        )
                    )

                    return .success(BackupTreeNodeSyncResult(id: folder.id, uuid: folder.uuid))
                } catch {
                    self.logger.error("❌ Failed to insert already created folder in database: \(error.getErrorDescription())")
                    return .failure(error)
                }
            }
            return .failure(error)
        }

    }

    private func syncNodeFile(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error> {
        self.logger.info("Creating file")
        let encryptedContentURL = self.getEncryptedContentURL(node: node)
        guard let safeEncryptedContentURL = encryptedContentURL else {
            return .failure(BackupUploadError.CannotCreateEncryptedContentURL)
        }

        guard let fileURL = node.url, let inputStream = InputStream(url: fileURL) else {
            return .failure(BackupUploadError.CannotOpenInputStream)
        }

        let filename = (node.name as NSString)
        self.logger.info("Starting backing up file \(filename)")

        guard let parentInfo = await waitForParentInfo(node: node) else {
            self.logger.info("Missing parent folderId \(node.name) after \(maxParentIdRetries) retries")
            return .failure(BackupUploadError.MissingParentFolder)
        }
        
        let remoteParentId = parentInfo.remoteParentId
        let remoteParentUuid = parentInfo.remoteParentUuid

        self.logger.info("Remote parent id \(remoteParentId)")

        do {
            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: safeEncryptedContentURL,
                fileSize: Int(fileURL.fileSize),
                bucketId: self.bucketId,
                progressHandler: { _ in }
            )

            self.logger.info("Upload completed with id \(result.id)")

            if node.syncStatus == .NEEDS_UPDATE {
                guard let remoteUuid = node.remoteUuid, let remoteId = node.remoteId else {
                    return .failure(BackupUploadError.MissingRemoteId)
                }

                let updatedFile = try await backupNewAPI.replaceFileId(
                    fileUuid: remoteUuid,
                    newFileId: result.id,
                    newSize: result.size
                )

                self.logger.info("✅ Updated file correctly with identifier \(updatedFile.fileId)")


                // Edit date in synced database
                try await editSyncedNodeDateSafely(remoteUuid: remoteUuid, date: Date())

                if encryptedContentURL != nil {
                    try FileManager.default.removeItem(at: encryptedContentURL!)
                }

                return .success(BackupTreeNodeSyncResult(id: remoteId, uuid: remoteUuid))
            } else {
                let stringRemoteParentId = "\(remoteParentId)"
                
                let encryptedFilename = try encrypt.encrypt(
                    string: filename.deletingPathExtension,
                    password: DecryptUtils().getDecryptPassword(bucketId: stringRemoteParentId),
                    salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                    iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
                )
           
                let createdFile = try await backupNewAPI.createBackupFileNew(
                    createFileData: CreateFileDataNew(
                        fileId: result.id,
                        type: filename.pathExtension,
                        bucket: result.bucket,
                        size: result.size,
                        folderId: remoteParentId,
                        name: encryptedFilename.base64EncodedString(),
                        plainName: filename.deletingPathExtension,
                        folderUuid: remoteParentUuid
                    )
                )
                self.logger.info("✅ Created file correctly with identifier \(createdFile.id)")


                try await addSyncedNodeSafely(
                    SyncedNode(
                        remoteId: createdFile.id,
                        deviceId: node.deviceId,
                        remoteUuid: createdFile.uuid,
                        url: fileURL,
                        rootBackupFolder: node.rootBackupFolder,
                        parentId: node.parentId,
                        remoteParentId: remoteParentId
                    )
                )

                if encryptedContentURL != nil {
                    if FileManager.default.fileExists(atPath: encryptedContentURL!.path) {
                        try FileManager.default.removeItem(at: encryptedContentURL!)
                    }else {
                        self.logger.info("ℹ️ℹ️ File does not exist at path: \(encryptedContentURL!.path)")
                    }
                    
                }

                return .success(BackupTreeNodeSyncResult(id: createdFile.id, uuid: createdFile.uuid))
            }

        } catch {

            if let uploadError = error as? UploadError, case .PartUploadFailed(let partIndex, let innerError) = uploadError {
                self.logger.error("❌ Part upload failed at index \(partIndex): \(uploadError.localizedDescription)")
                self.logger.info("ℹ️ Inner error details: \(String(describing: innerError))")
            } else {
                self.logger.error("❌ Failed to create file \(node.name) in \(String(describing: node.remoteParentId)): \(error.getErrorDescription())")
            }
            if let startUploadError = error as? StartUploadError {
                if let apiClientError = startUploadError.apiError,  apiClientError.statusCode == 420 {
                    self.logger.error("❌ Failed to create file \(node.name) in \(String(describing: node.remoteParentId)): Max space used")
                }
            }

            
            if encryptedContentURL != nil {
                try? FileManager.default.removeItem(at: encryptedContentURL!)
            }

            if let apiClientError = error as? APIClientError, apiClientError.statusCode == 409 {
                // Handle duplicated folder error
                do {
                    let existenceFile = ExistenceFile(plainName: filename.deletingPathExtension, type: filename.pathExtension)

                    
                    let result = try await backupNewAPI.getExistenceFileInFolderByPlainName(uuid: remoteParentUuid, files: [existenceFile])
                    
                    let nodePlainName = (node.name as NSString).deletingPathExtension
  
                    let matchingFile = result.existentFiles.first {
                        $0.plainName == nodePlainName
                    }
                
                    guard let file = matchingFile else {
                        return .failure(BackupUploadError.CannotFindNodeInServer)
                    }

                    try await addSyncedNodeSafely(
                        SyncedNode(
                            remoteId: file.id,
                            deviceId: node.deviceId,
                            remoteUuid: file.uuid,
                            url: fileURL,
                            rootBackupFolder: node.rootBackupFolder,
                            parentId: node.parentId,
                            remoteParentId: remoteParentId
                        )
                    )

                    return .success(BackupTreeNodeSyncResult(id: file.id, uuid: file.uuid))
                } catch {
                    self.logger.error("❌ Failed to insert already created folder in database: \(error.getErrorDescription())")
                    return .failure(error)
                }
            }

            return .failure(error)
        }

    }


}

