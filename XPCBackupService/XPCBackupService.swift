//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation
import InternxtSwiftCore

public class XPCBackupService: NSObject, XPCBackupServiceProtocol {
    
    private var backupUploadService: BackupUploadService? = nil
    private var trees: [BackupTreeNode] = []
    private let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "XPCBackupService")
    private var backupTotalProgress: Progress = Progress()
    private var status: BackupStatus = .Idle
    
    @objc func startBackup(
        backupAt backupURLs: [String],
        mnemonic: String,
        networkAuth: String?,
        authToken: String,
        newAuthToken: String,
        deviceId: Int,
        bucketId: String,
        with reply: @escaping (_ result: String?, _ error: String?) -> Void
    ) -> Void {
        
        logger.info("Going to backup folders: \(backupURLs)")
        self.status = .InProgress
        self.backupTotalProgress = Progress()
        
        Task {
            
            guard let networkAuth = networkAuth else {
                logger.error("Cannot get network auth")
                reply(nil, "Cannot get network auth")
                return
            }

            let configLoader = ConfigLoader()
            let config = configLoader.get()
            let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: CLIENT_NAME, clientVersion: getVersion())

            backupUploadService = BackupUploadService(
                networkFacade: NetworkFacade(mnemonic: mnemonic, networkAPI: networkAPI),
                encryptedContentDirectory: FileManager.default.temporaryDirectory,
                deviceId: deviceId,
                bucketId: bucketId,
                authToken: authToken,
                newAuthToken: newAuthToken
            )

            
            guard let backupUploadService = backupUploadService else {
                logger.error("Cannot create backup upload service")
                reply(nil, "Cannot create backup upload service")
                return
            }

            backupUploadService.canDoBackup = true

            var totalCount = backupURLs.count
            for backupURL in backupURLs {
                let count = self.getNodesCountFromURL(URL(fileURLWithPath: backupURL))
                totalCount += count
            }

            logger.info("Total progress to backup \(totalCount)")

            backupTotalProgress.totalUnitCount = Int64(totalCount)
            
            for backupURL in backupURLs {
                do {
                    let backupTreeGenerator = BackupTreeGenerator(
                        root: URL(fileURLWithPath: backupURL),
                        deviceId: deviceId,
                        backupUploadService: backupUploadService,
                        backupTotalProgress: backupTotalProgress
                    )

                    let backupTree = try await backupTreeGenerator.generateTree()
                    logger.info("Backup tree created successfully")

                    trees.append(backupTree)
                } catch {
                    logger.error(["Unable to create backup tree for \(backupURL)", error])
                }
                
            }
            
            
            
            for backupTree in trees {
                do {
                    try await backupTree.syncNodes()
                } catch {
                    self.status = .Failed
                    logger.error("Error backing up device \(error)")
                    Analytics.shared.track(event: FailureBackupEvent(foldersToBackup: backupURLs.count, error: error))
                    reply(nil, error.localizedDescription)
                }
            }

            self.status = .Done
            Analytics.shared.track(event: SuccessBackupEvent(foldersToBackup: backupURLs.count))
            logger.info(["Backup sync status: \(backupTotalProgress.completedUnitCount) of \(backupTotalProgress.totalUnitCount) nodes synced"])
            reply("synced all nodes for all trees", nil)

        }

    }

    @objc func stopBackup() {
        logger.debug("STOP BACKUP")
        trees = []
        self.status = .Stopped
        backupUploadService?.stopSync()
    }
    
    
    
    func getBackupStatus(with reply: @escaping (BackupProgressUpdate?, String?) -> Void) {
        logger.info(["Backup sync status: \(backupTotalProgress.completedUnitCount) of \(backupTotalProgress.totalUnitCount) nodes synced"])
        reply(BackupProgressUpdate(status: self.status, progress: backupTotalProgress), nil)
    }

    private func getNodesCountFromURL(_ url: URL) -> Int {
        
        var count = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                do {
                    let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
                    if fileAttributes.isRegularFile! || fileAttributes.isDirectory! {
                        count += 1
                    }
                } catch {
                    print("Error listing files for \(fileURL)", error)
                }
            }
        }

        return count
    }

}
