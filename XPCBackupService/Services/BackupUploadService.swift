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
    case CannotCreateEncryptedContentURL
}

struct BackupUploadService {
    private let logger = Logger(subsystem: "com.internxt", category: "BackupUpload")
    private let cryptoUtils = CryptoUtils()
    private let encrypt: Encrypt = Encrypt()
    private let config = ConfigLoader().get()
    private let networkFacade: NetworkFacade
    private let networkQueue = OperationQueue()
    private let completionQueue = OperationQueue()
    private let encryptedContentDirectory: URL
    private let retriesCount = 3
    private let backupProgress: Progress
    private let deviceId: Int
    private let bucketId: String
    private let authToken: String

    init(networkFacade: NetworkFacade, encryptedContentDirectory: URL, deviceId: Int, bucketId: String, authToken: String, backupProgress: Progress) {
        self.networkFacade = networkFacade
        self.encryptedContentDirectory = encryptedContentDirectory
        self.deviceId = deviceId
        self.bucketId = bucketId
        self.authToken = authToken
        self.backupProgress = backupProgress
    }

    // TODO: get auth token from user defaults from XPC Service.
    private var backupAPI: BackupAPI {
        return BackupAPI(baseUrl: config.DRIVE_API_URL, authToken: authToken, clientName: CLIENT_NAME, clientVersion: getVersion())
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

    func getEncryptedContentURL(node: BackupTreeNode) throws -> URL {
        let url = encryptedContentDirectory.appendingPathComponent(node.id)

        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)

        FileManager.default.createFile(atPath: url.path(), contents: nil)

        return url
    }

    func doSync(node: BackupTreeNode, progress: Progress) async throws -> Int {
        if (node.type == .folder) {
            return try await self.syncNodeFolder(node: node, progress: progress)
        }
        return try await self.syncNodeFile(node: node, progress: progress)
    }

    func syncNodeFolder(node: BackupTreeNode, progress: Progress) async throws -> Int {
        self.logger.info("Creating folder")

        do {
            var remoteParentId: Int? = nil
            let foldername = node.name
            self.logger.info("Going to create folder \(foldername)")

            if let _ = node.parentId {
                guard let parentId = node.remoteParentId else {
                    throw BackupUploadError.MissingParentFolder
                }

                remoteParentId = parentId
            } else {
                remoteParentId = self.deviceId
            }

            guard let safeRemoteParentId = remoteParentId else {
                throw BackupUploadError.MissingParentFolder
            }

            self.logger.info("Parent id \(safeRemoteParentId)")

            let createdFolder = try await backupAPI.createBackupFolder(
                parentFolderId: safeRemoteParentId,
                folderName: foldername
            )

            self.logger.info("✅ Folder created successfully: \(createdFolder.id)")
            progress.completedUnitCount = 1
            return createdFolder.id
        } catch {
            self.logger.error("❌ Failed to create folder: \(self.getErrorDescription(error: error))")
            progress.completedUnitCount = 1
            throw error
        }
    }

    func syncNodeFile(node: BackupTreeNode, progress: Progress) async throws -> Int {
        self.logger.info("Creating file")

        var encryptedContentURL: URL? = nil
        do {
            encryptedContentURL = try self.getEncryptedContentURL(node: node)
            guard let safeEncryptedContentURL = encryptedContentURL else {
                throw BackupUploadError.CannotCreateEncryptedContentURL
            }

            guard let fileURL = node.url, let inputStream = InputStream(url: fileURL) else {
                throw BackupUploadError.CannotOpenInputStream
            }

            let filename = (node.name as NSString)
            self.logger.info("Starting backing up file \(filename)")

            guard let remoteParentId = node.remoteParentId else {
                throw BackupUploadError.MissingParentFolder
            }

            self.logger.info("Remote parent id \(remoteParentId)")

            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: safeEncryptedContentURL,
                fileSize: Int(fileURL.fileSize),
                bucketId: self.bucketId,
                progressHandler: { _ in }
            )

            self.logger.info("Upload completed with id \(result.id)")

            let stringRemoteParentId = "\(remoteParentId)"

            let encryptedFilename = try encrypt.encrypt(
                string: filename.deletingPathExtension,
                password: "\(config.CRYPTO_SECRET2)-\(stringRemoteParentId)",
                salt: cryptoUtils.hexStringToBytes(config.MAGIC_SALT_HEX),
                iv: Data(cryptoUtils.hexStringToBytes(config.MAGIC_IV_HEX))
            )

            let createdFile = try await backupAPI.createBackupFile(
                createFileData: CreateFileData(
                    fileId: result.id,
                    type: filename.pathExtension,
                    bucket: result.bucket,
                    size: result.size,
                    folderId: remoteParentId,
                    name: encryptedFilename.base64EncodedString(),
                    plainName: filename.deletingPathExtension
                )
            )

            self.logger.info("✅ Created file correctly with identifier \(createdFile.id)")

            progress.completedUnitCount = 1

            if encryptedContentURL != nil {
                try FileManager.default.removeItem(at: encryptedContentURL!)
            }

            return createdFile.id
        } catch {
            self.logger.error("❌ Failed to create file: \(self.getErrorDescription(error: error))")

            progress.completedUnitCount = 1

            if encryptedContentURL != nil {
                try? FileManager.default.removeItem(at: encryptedContentURL!)
            }

            throw error
        }

    }

    private func getErrorDescription(error: Error) -> String {
        if let apiClientError = error as? APIClientError {
            let responseBody = String(decoding: apiClientError.responseBody, as: UTF8.self)
            return "APIClientError \(apiClientError.statusCode) - \(responseBody)"
        }
        return error.localizedDescription
    }

}
