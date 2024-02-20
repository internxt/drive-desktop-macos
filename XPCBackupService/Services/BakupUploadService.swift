//
//  BakupUploadService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/15/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

enum BackupUploadError: Error {
    case CannotOpenInputStream
    case MissingDocumentSize
    case MissingParentFolder
}

struct BackupUploadService {
    private let logger = Logger(subsystem: "com.internxt", category: "BackupUpload")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let config = ConfigLoader().get()
    private let backupAPI = APIFactory.Backup
    private let networkFacade: NetworkFacade
    private let networkQueue = OperationQueue()
    private let completionQueue = OperationQueue()
    private let encryptedFileDestination: URL
    private let retriesCount = 3

    init(networkFacade: NetworkFacade, encryptedFileDestination: URL) {
        self.networkFacade = networkFacade
        self.encryptedFileDestination = encryptedFileDestination
    }

    func syncOperation(node: BackupTreeNode) {
        BackupOperation(node: node, attempLimit: retriesCount)
            .enqueue(in: networkQueue)
            .addCompletionOperation(on: completionQueue) { operation in
                if let result = operation.result {
                    dump(result)
                } else if let error = operation.lastError {
                    dump(error)
                } else {
                    dump("Unknown Error")
                }
            }
            .start()

        completionQueue.waitUntilAllOperationsAreFinished()
    }

    private func getDeviceBucketId() async throws -> String {
        if let bucketId = try await DeviceService.shared.getCurrentDevice()?.bucket {
            return bucketId
        }
        return ""
    }

    func syncNodeFolder(node: BackupTreeNode) -> Progress {
        self.logger.info("Creating folder")

        Task {
            do {
                let foldername = node.name
                self.logger.info("Parent id \(node.parentId ?? "no-parent")")

                guard let remoteParentId = node.remoteParentId, let folderId = Int(remoteParentId) else {
                    throw BackupUploadError.MissingParentFolder
                }

                let createdFolder = try await backupAPI.createBackupFolder(
                    parentFolderId: folderId,
                    folderName: foldername
                )

                self.logger.info("✅ Folder created successfully: \(createdFolder.id)")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to create folder: \(error.localizedDescription)")
            }
        }

        return Progress()
    }

    func syncNodeFile(node: BackupTreeNode) -> Progress {
        self.logger.info("Creating file")

        Task {
            do {
                guard let fileURL = node.url, let inputStream = InputStream(url: fileURL) else {
                    throw BackupUploadError.CannotOpenInputStream
                }

                let filename = (node.name as NSString)
                self.logger.info("Starting backing up file \(filename)")
                self.logger.info("Parent id \(node.parentId ?? "no-parent")")

                guard let remoteParentId = node.remoteParentId, let folderId = Int(remoteParentId) else {
                    throw BackupUploadError.MissingParentFolder
                }

                let result = try await networkFacade.uploadFile(
                    input: inputStream,
                    encryptedOutput: encryptedFileDestination,
                    fileSize: Int(fileURL.fileSize),
                    bucketId: self.getDeviceBucketId()
                ) { _ in }

                self.logger.info("Upload completed with id \(result.id)")

                let encryptedFilename = try encrypt.encrypt(
                    string: filename.deletingPathExtension,
                    password: DecryptUtils().getDecryptPassword(bucketId: node.parentId ?? ""),
                    salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                    iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
                )

                let createdFile = try await backupAPI.createBackupFile(
                    createFileData: CreateFileData(
                        fileId: result.id,
                        type: filename.pathExtension,
                        bucket: result.bucket,
                        size: result.size,
                        folderId: folderId,
                        name: encryptedFilename.base64EncodedString(),
                        plainName: filename.deletingPathExtension
                    )
                )

                self.logger.info("✅ Created file correctly with identifier \(createdFile.uuid)")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to create file: \(error.localizedDescription)")
            }
        }

        return Progress()
    }

}
