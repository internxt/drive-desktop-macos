//
//  BackupDownloadService.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 12/6/24.
//

import Foundation
import InternxtSwiftCore

struct BackupDownloadService {
    let downloadOperationQueue: OperationQueue
    let backupAPI: BackupAPI
    let driveNewAPI: DriveAPI
    let networkFacade: NetworkFacade
    let encryptedContentURL: URL
    let decrypt: Decrypt
    let backupBucket: String
    let backupDownloadProgress: Progress
    
    func downloadDeviceBackup(deviceId: Int, downloadAt: URL) async throws {
        let deviceBackupFolders = try await backupAPI.getBackupChilds(folderId: String(deviceId))
        backupDownloadProgress.totalUnitCount += Int64(deviceBackupFolders.result.count)
        for deviceBackupFolder in deviceBackupFolders.result {
            let backupFolderName = try deviceBackupFolder.plainName ?? self.decryptName(name: deviceBackupFolder.name, bucketId: backupBucket)
            let backupFolderURL = self.getURLForItem(baseURL: downloadAt, itemName: backupFolderName)
            let creationDate = Time.dateFromISOString(deviceBackupFolder.createdAt) ?? Date()
            try self.createFolder(folderURL: backupFolderURL, creationDate: creationDate)
            backupDownloadProgress.completedUnitCount += 1
            try await self.downloadBackupFolderAtPath(
                folderId: String(deviceBackupFolder.id),
                downloadAtPath: backupFolderURL
            )
        }
    }
    
    func downloadBackupFolderAtPath(folderId: String, downloadAtPath: URL) async throws {
      
        let folderStream = Paginator.paginate { offset, limit in
            let response = try await backupAPI.getBackupChilds(folderId: folderId, offset: offset, limit: limit)
            return response.result
        }

        for try await backupFolder in folderStream {
            backupDownloadProgress.totalUnitCount += 1

            let backupFolderName = try backupFolder.plainName ?? self.decryptName(name: backupFolder.name, bucketId: backupBucket)
            let folderURL = self.getURLForItem(baseURL: downloadAtPath, itemName: backupFolderName)
            let creationDate = Time.dateFromISOString(backupFolder.createdAt) ?? Date()
            try self.createFolder(folderURL: folderURL, creationDate: creationDate)
            logger.info("📁 Folder created at \(folderURL.path)")
            Task {
                do {
                    try await self.downloadBackupFolderAtPath(folderId: String(backupFolder.id), downloadAtPath: folderURL)
                } catch {
                    logger.error("❌ Failed to download backup folder \(backupFolderName) at \(downloadAtPath.path)")
                }
            }
        }

        let fileStream = Paginator.paginate { offset, limit in
            let response = try await backupAPI.getBackupFiles(folderId: folderId, offset: offset, limit: limit)
            return response.result
        }

        for try await backupFile in fileStream {
            backupDownloadProgress.totalUnitCount += 1

            let backupFileName = try backupFile.plainName ?? self.decryptName(name: backupFile.name, bucketId: backupFile.bucket)
            logger.info("📄 Filename to download \(backupFileName)")
            let fileURL = self.getURLForItem(baseURL: downloadAtPath, itemName: backupFileName, itemType: backupFile.type)
            self.downloadFile(
                fileId: backupFile.fileId,
                bucketId: backupBucket,
                downloadAt: fileURL
            )
        }
    }
    
    func downloadFolderBackup(folderId: String, downloadAtPath: URL,folderName: String) async throws {
        if folderName.isEmpty {
            try await self.downloadBackupFolderAtPath(
                folderId: folderId,
                downloadAtPath: downloadAtPath
            )
        }else{
            let folderURL = self.getURLForItem(
                baseURL: downloadAtPath, itemName: folderName
            )
            let creationDate = Date()
            try self.createFolder(folderURL: folderURL, creationDate: creationDate)
            try await self.downloadBackupFolderAtPath(
                folderId: folderId,
                downloadAtPath: folderURL
            )
        }

    }
    
    func downloadFile(fileId: String, bucketId: String, downloadAt: URL) {
        let downloadFileOperation = BackupDownloadItemOperation(
            networkFacade: self.networkFacade,
            bucketId: bucketId,
            fileId: fileId,
            encryptedContentURL: encryptedContentURL,
            downloadAt: downloadAt,
            backupDownloadProgress: self.backupDownloadProgress
        )
        self.downloadOperationQueue.addOperation(downloadFileOperation)
    }
    

    
    
    
    private func createFolder(folderURL: URL, creationDate: Date) throws {
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories:true, attributes: [.creationDate: creationDate])
    }
    
    
    
    private func getURLForItem(baseURL: URL, itemName: String, itemType: String? = nil) -> URL {
        let type: String = (itemType != nil) ? ".\(itemType!)" : ""
        
        return baseURL.appendingPathComponent("\(itemName)\(type)")
    }
    
    func decryptName(name: String, bucketId: String) throws -> String {
        return try decrypt.decrypt(base64String: name, password: DecryptUtils().getDecryptPassword(bucketId: bucketId))
    }
}
