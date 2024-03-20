//
//  BackupClient.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 3/20/24.
//

import Foundation
import InternxtSwiftCore

protocol HTTPClientProtocol {
    func createBackupFolder(parentFolderId: Int, folderName: String, backupAPI: BackupAPI) async -> Result<CreateFolderResponse, Error>
    func createBackupFile(fileId: String, type: String, bucket: String, size: Int, remoteParentId: Int, name: String, plainName: String, backupAPI: BackupAPI) async -> Result<CreateFileResponse, Error>
    func replaceFileId(fileUuid: String, newFileId: String, newSize: Int, backupNewAPI: BackupAPI) async -> Result<ReplaceFileResponse, Error>
    func uploadFile(inputStream: InputStream, encryptedOutput: URL, fileSize: Int, bucketId: String, networkFacade: NetworkFacade) async -> Result<FinishUploadResponse, Error>
}

final class BackupClient: HTTPClientProtocol {

    static let shared = BackupClient()

    private init() {}

    func createBackupFile(fileId: String, type: String, bucket: String, size: Int, remoteParentId: Int, name: String, plainName: String, backupAPI: BackupAPI) async -> Result<CreateFileResponse, Error> {
        do {
            let createFileResponse = try await backupAPI.createBackupFile(
                createFileData: CreateFileData(
                    fileId: fileId,
                    type: type,
                    bucket: bucket,
                    size: size,
                    folderId: remoteParentId,
                    name: name,
                    plainName: plainName
                )
            )
            return .success(createFileResponse)
        } catch {
            return .failure(error)
        }
    }

    func createBackupFolder(parentFolderId: Int, folderName: String, backupAPI: BackupAPI) async -> Result<CreateFolderResponse, Error> {
        do {
            let createFolderResponse = try await backupAPI.createBackupFolder(
                parentFolderId: parentFolderId,
                folderName: folderName
            )
            return .success(createFolderResponse)
        } catch {
            return .failure(error)
        }
    }

    func replaceFileId(fileUuid: String, newFileId: String, newSize: Int, backupNewAPI: BackupAPI) async -> Result<ReplaceFileResponse, Error> {
        do {
            let updatedFile = try await backupNewAPI.replaceFileId(
                fileUuid: fileUuid,
                newFileId: newFileId,
                newSize: newSize
            )
            return .success(updatedFile)
        } catch {
            return .failure(error)
        }
    }

    func uploadFile(inputStream: InputStream, encryptedOutput: URL, fileSize: Int, bucketId: String, networkFacade: NetworkFacade) async -> Result<FinishUploadResponse, Error> {
        do {
            let result = try await networkFacade.uploadFile(
                input: inputStream,
                encryptedOutput: encryptedOutput,
                fileSize: fileSize,
                bucketId: bucketId,
                progressHandler: { _ in }
            )

            return .success(result)
        } catch {
            return .failure(error)
        }
    }

}
