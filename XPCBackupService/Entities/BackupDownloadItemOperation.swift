//
//  BackupDownloadItemOperation.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 14/6/24.
//

import Foundation
import InternxtSwiftCore
let MAX_DOWNLOAD_ATTEMPTS = 3
class BackupDownloadItemOperation: AsyncOperation {
    
    let networkFacade: NetworkFacade
    let bucketId: String
    let fileId: String
    let encryptedContentURL: URL
    let downloadAt: URL
    let backupDownloadProgress: Progress
    var downloadAttempts = 0
    init(networkFacade: NetworkFacade, bucketId: String, fileId: String, encryptedContentURL: URL, downloadAt: URL, backupDownloadProgress: Progress) {
        self.networkFacade = networkFacade
        self.bucketId = bucketId
        self.fileId = fileId
        self.encryptedContentURL = encryptedContentURL
        self.downloadAt = downloadAt
        self.backupDownloadProgress = backupDownloadProgress
    }
    
    
    override func performAsyncTask() async throws -> Void {
        do {
            self.downloadAttempts += 1
            logger.info("⬇️ Downloading file at \(downloadAt.path) with fileID \(fileId)")
            let encryptedFileURL = self.encryptedContentURL.appendingPathComponent(UUID().uuidString)
           
            let _ = try await networkFacade.downloadFile(
                bucketId: bucketId,
                fileId: fileId,
                encryptedFileDestination: encryptedFileURL,
                destinationURL: downloadAt,
                progressHandler: { completedProgress in },
                debug: true
            )
            
            backupDownloadProgress.completedUnitCount += 1
            
            defer {
                logger.info("🧹 Cleaning up encrypted file...")
                try? FileManager.default.removeItem(at: encryptedContentURL)
            }
            
            logger.info("✅ File downloaded at \(downloadAt.path)")
        } catch {
            if downloadAttempts == MAX_DOWNLOAD_ATTEMPTS {
                logger.error("❌ Failed to download file at \(downloadAt.path)")
            } else {
                logger.error("🔄 Retrying file download, attempt #\(downloadAttempts) for file at \(downloadAt.path)")
                try? await self.performAsyncTask()
            }
            
        }
        
    }
}
