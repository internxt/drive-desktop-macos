//
//  BackupDownloadItemOperation.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 14/6/24.
//

import Foundation
import InternxtSwiftCore
class BackupDownloadItemOperation: AsyncOperation {
    let networkFacade: NetworkFacade
    let bucketId: String
    let fileId: String
    let encryptedContentURL: URL
    let downloadAt: URL
    let backupDownloadProgress: Progress
    
    init(networkFacade: NetworkFacade, bucketId: String, fileId: String, encryptedContentURL: URL, downloadAt: URL, backupDownloadProgress: Progress) {
        self.networkFacade = networkFacade
        self.bucketId = bucketId
        self.fileId = fileId
        self.encryptedContentURL = encryptedContentURL
        self.downloadAt = downloadAt
        self.backupDownloadProgress = backupDownloadProgress
    }
    
    
    override func performAsyncTask() async throws -> Void {
        logger.info("⬇️ Downloading file at \(downloadAt.path) with fileID \(fileId)")
        let encryptedFileURL = self.encryptedContentURL.appendingPathComponent(UUID().uuidString)
       
        let _ = try await networkFacade.downloadFile(
            bucketId: bucketId,
            fileId: fileId,
            encryptedFileDestination: encryptedFileURL,
            destinationURL: downloadAt,
            progressHandler: { completedProgress in }
        )
        
        backupDownloadProgress.completedUnitCount += 1
        
        defer {
            logger.info("🧹 Cleaning up encrypted file...")
            try? FileManager.default.removeItem(at: encryptedContentURL)
        }
        
        logger.info("✅ File downloaded at \(downloadAt.path)")
    }
}
