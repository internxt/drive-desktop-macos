//
//  MockBackupClien.swift
//  InternxtDesktopTests
//
//  Created by Richard Ascanio on 3/20/24.
//

import Foundation
import InternxtSwiftCore
@testable import XPCBackupService

class MockBackupClient: HTTPClientProtocol {

    var shouldReturnError = false

    func createBackupFolder(parentFolderId: Int, folderName: String, backupAPI: BackupAPI) async -> Result<CreateFolderResponse, any Error> {
        if shouldReturnError {
            return .failure(BackupUploadError.CannotUploadFolder)
        }

        let jsonResponse = """
            {
                "bucket": "bucket-id",
                "id": 839,
                "name": "folder-name",
                "plain_name": "",
                "parentId": 83944,
                "createdAt": "create-date",
                "updatedAt": "update-date",
                "userId": 62733
            }
        """.data(using: .utf8)!

        guard let response = try? JSONDecoder().decode(CreateFolderResponse.self, from: jsonResponse) else {
            return .failure(BackupUploadError.CannotUploadFolder)
        }

        return .success(response)
    }

    func createBackupFile(fileId: String, type: String, bucket: String, size: Int, remoteParentId: Int, name: String, plainName: String, backupAPI: BackupAPI) async -> Result<CreateFileResponse, any Error> {
        if shouldReturnError {
            return .failure(BackupUploadError.CannotUploadFile)
        }

        let jsonResponse = """
            {
                "created_at": "created-at-date",
                "deleted": false,
                "status": "active",
                "id": 2873,
                "name": "File name",
                "plain_name": "file plain name",
                "type": "json",
                "size": "100",
                "folderId": 238823,
                "fileId": "wqoi832",
                "bucket": "dwidu237862",
                "encrypt_version": "qwiuehqw",
                "userId": 72323,
                "modificationTime": "modification-time",
                "updatedAt": "updated-at",
                "createdAt": "created-at",
                "deletedAt": "deleted-at",
                "uuid": "q98273hwwe",
            }
        """.data(using: .utf8)!

        guard let response = try? JSONDecoder().decode(CreateFileResponse.self, from: jsonResponse) else {
            return .failure(BackupUploadError.CannotUploadFolder)
        }

        return .success(response)
    }

    func replaceFileId(fileUuid: String, newFileId: String, newSize: Int, backupNewAPI: BackupAPI) async -> Result<ReplaceFileResponse, any Error> {
        if shouldReturnError {
            return .failure(BackupUploadError.CannotUploadFile)
        }

        let jsonResponse = """
            {
                "uuid": "q98273hwwe",
                "fileId": "wqoi832",
                "size": 100,
            }
        """.data(using: .utf8)!

        guard let response = try? JSONDecoder().decode(ReplaceFileResponse.self, from: jsonResponse) else {
            return .failure(BackupUploadError.CannotUploadFolder)
        }

        return .success(response)
    }

    func uploadFile(inputStream: InputStream, encryptedOutput: URL, fileSize: Int, bucketId: String, networkFacade: NetworkFacade) async -> Result<FinishUploadResponse, any Error> {
        if shouldReturnError {
            return .failure(BackupUploadError.CannotUploadFile)
        }

        let jsonResponse = """
            {
                "bucket": "bucket-id",
                "index": "839",
                "size": 23
                "version": 2,
                "created": "created-at",
                "renewal": "renewal",
                "mimetype": "",
                "filename": "organization.json",
                "id": "qwuy7qw"
            }
        """.data(using: .utf8)!

        guard let response = try? JSONDecoder().decode(FinishUploadResponse.self, from: jsonResponse) else {
            return .failure(BackupUploadError.CannotUploadFolder)
        }

        return .success(response)
    }

}
