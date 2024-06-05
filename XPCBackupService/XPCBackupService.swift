//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation
import InternxtSwiftCore

let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "XPCBackupService")
public class XPCBackupService: NSObject, XPCBackupServiceProtocol {
    
    private var backupUploadService: BackupUploadService? = nil
    private var trees: [BackupTreeNode] = []
    
    private var backupTotalProgress: Progress = Progress()
    private var uploadOperationQueue = OperationQueue()
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
        let backupRealm = BackupRealm.shared
        self.uploadOperationQueue.maxConcurrentOperationCount = 10
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
            
            
            guard let backupUploadService = self.backupUploadService else {
                logger.error("Cannot create backup upload service")
                reply(nil, "Cannot create backup upload service")
                return
            }

            backupUploadService.canDoBackup = true

            
            var totalNodesCount = 0

            
          
            for backupURL in backupURLs {
                do {
                    let startGeneratingTreeAt = Date()
                    let nodesCount = self.getNodesCountFromURL(URL(fileURLWithPath: backupURL))
                    totalNodesCount += nodesCount
                    let backupTreeGenerator = BackupTreeGenerator(
                        root: URL(fileURLWithPath: backupURL),
                        deviceId: deviceId,
                        backupUploadService: backupUploadService,
                        backupTotalProgress: self.backupTotalProgress,
                        backupRealm: backupRealm
                    )

                    let backupTree = try await backupTreeGenerator.generateTree()
                    let elapsedTime = Date().timeIntervalSince(startGeneratingTreeAt)
                    logger.info("🌳 Backup tree created successfully in \(Float(elapsedTime * 1000))ms with \(nodesCount) nodes ")

                    trees.append(backupTree)
                } catch {
                    logger.error(["Unable to create backup tree for \(backupURL)", error])
                }
                
            }
            
            backupTotalProgress.totalUnitCount = Int64(totalNodesCount)
            logger.info("Total progress to backup \(totalNodesCount)")

            logger.info("⏱️ About to start node sync process for \(trees.count) BackupTrees...")
            
            for backupTree in trees {
                do {
                    logger.error("Adding nodes sync operations")
                    try backupTree.syncBelowNodes(withOperationQueue: self.uploadOperationQueue)
                } catch {
                    self.status = .Failed
                    logger.error("Error backing up device \(error)")
                    reply(nil, error.localizedDescription)
                }
            }
            
            self.uploadOperationQueue.addBarrierBlock {
                logger.info("Sync nodes operations completed")
                self.status = .Done
                
                self.trees = []
                self.uploadOperationQueue.cancelAllOperations()
                reply("synced all nodes for all trees", nil)
            }

            logger.info("Backups scheduled in OperationQueue")
            self.status = .Done
            logger.info(["Backup sync status: \(backupTotalProgress.completedUnitCount) of \(backupTotalProgress.totalUnitCount) nodes synced"])

        }

    }

    @objc func stopBackup() {
        logger.debug("STOP BACKUP")
        trees = []
        
        self.status = .Stopped
        self.uploadOperationQueue.cancelAllOperations()
        backupUploadService?.stopSync()
    }
    
    
    
    func getBackupStatus(with reply: @escaping (BackupProgressUpdate?, String?) -> Void) {
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
