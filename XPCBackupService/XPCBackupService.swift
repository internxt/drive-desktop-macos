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
    
    private var backupUploadProgress: Progress = Progress()
    private var backupDownloadProgress: Progress = Progress()
    private var uploadOperationQueue = OperationQueue()
    private var downloadOperationQueue = OperationQueue()
    private var backupUploadStatus: BackupStatus = .Idle
    private var backupDownloadStatus: BackupStatus = .Idle
    private let AUTH_TOKEN_KEY = "AuthToken"
    private let LEGACY_TOKEN_KEY = "LegacyAuthToken"
    private let MNEMONIC_TOKEN_KEY = "Mnemonic"
    @objc func uploadDeviceBackup(
        backupAt backupURLs: [String],
        networkAuth: String?,
        deviceId: Int,
        bucketId: String,
        with reply: @escaping (_ result: String?, _ error: String?) -> Void
    ) -> Void {
        let backupRealm = SyncedNodeRepository.shared
        self.uploadOperationQueue.maxConcurrentOperationCount = 10
        logger.info("Going to backup folders: \(backupURLs)")
        self.backupUploadStatus = .InProgress
        self.backupUploadProgress = Progress()
        
        Task {
            
            guard let networkAuth = networkAuth else {
                logger.error("Cannot get network auth")
                reply(nil, "Cannot get network auth")
                return
            }
            
            guard let sharedDefaults = UserDefaults(suiteName: INTERNXT_GROUP_NAME) else {
                logger.error("Cannot get sharedDefaults")
                reply(nil, "Cannot get sharedDefaults")
                return
            }
            
            guard let authToken = sharedDefaults.string(forKey: LEGACY_TOKEN_KEY) else{
                logger.error("Cannot get LegacyAuthToken")
                reply(nil, "Cannot get LegacyAuthToken")
                return
            }
            
            guard let newAuthToken = sharedDefaults.string(forKey: AUTH_TOKEN_KEY) else{
                logger.error("Cannot get AuthToken")
                reply(nil, "Cannot get AuthToken")
                return
            }
            
            guard let mnemonic = sharedDefaults.string(forKey: MNEMONIC_TOKEN_KEY) else{
                logger.error("Cannot get mnemonic")
                reply(nil, "Cannot get mnemonic")
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

            
            var totalNodesCount = backupURLs.count

            for backupURL in backupURLs {
                do {
                    let startGeneratingTreeAt = Date()
                    let nodesCount = self.getNodesCountFromURL(URL(fileURLWithPath: backupURL))
                    totalNodesCount += nodesCount
                    let backupTreeGenerator = BackupTreeGenerator(
                        root: URL(fileURLWithPath: backupURL),
                        deviceId: deviceId,
                        backupUploadService: backupUploadService,
                        backupTotalProgress: self.backupUploadProgress,
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
            
            backupUploadProgress.totalUnitCount = Int64(totalNodesCount)
            logger.info("Total progress to backup \(totalNodesCount)")

            logger.info("⏱️ About to start node sync process for \(trees.count) BackupTrees...")
            
            for backupTree in trees {
                do {
                    logger.error("Adding nodes sync operations")
                    try backupTree.syncBelowNodes(withOperationQueue: self.uploadOperationQueue)
                } catch {
                    self.backupUploadStatus = .Failed
                    logger.error("Error backing up device \(error)")
                    reply(nil, error.localizedDescription)
                }
            }
            
            self.uploadOperationQueue.addBarrierBlock {
                logger.info("Sync nodes operations completed")
                // If the backup failed, don't set the status to Done
                if self.backupUploadStatus != .Failed {
                    self.backupUploadStatus = .Done
                }
                
                self.trees = []
                reply("synced all nodes for all trees", nil)
            }

            logger.info("Backups scheduled in OperationQueue")
            
           
            
            logger.info(["Backup sync status: \(backupUploadProgress.completedUnitCount) of \(backupUploadProgress.totalUnitCount) nodes synced"])

        }

    }
    
    @objc func downloadDeviceBackup(
        downloadAt downloadAtURL: String,
        networkAuth: String,
        deviceId: Int,
        bucketId: String,
        with reply: @escaping (_ result: String?, _ error: String?) -> Void
    ) {
        self.backupDownloadStatus = .InProgress
        self.backupDownloadProgress = Progress()
        let downloadAtURL = URL(fileURLWithPath: downloadAtURL)
        let configManager = BackupConfigurationManager(groupName: INTERNXT_GROUP_NAME, clientName: CLIENT_NAME)
       
        guard let (backupAPI, driveNewAPI, networkFacade) = configManager.setupAPIs(networkAuth: networkAuth) else {
            reply(nil, "Setup failed")
            return
        }
        

        self.downloadOperationQueue.maxConcurrentOperationCount = 10
        
        let backupDownloadService = BackupDownloadService(
            downloadOperationQueue: downloadOperationQueue,
            backupAPI: backupAPI,
            driveNewAPI: driveNewAPI,
            networkFacade: networkFacade,
            encryptedContentURL: FileManager.default.temporaryDirectory,
            decrypt: Decrypt(),
            backupBucket: bucketId,
            backupDownloadProgress: backupDownloadProgress
        )
        Task {
            do {
                try await backupDownloadService.downloadDeviceBackup(deviceId: deviceId, downloadAt: downloadAtURL)
                self.downloadOperationQueue.addBarrierBlock {
                    logger.info("Download operations completed")
                    self.backupDownloadStatus = .Done
                    reply(nil, nil)
                }
                
                
            } catch {
                self.backupDownloadStatus = .Failed
                logger.error(["Failed to download backup", error])
                error.reportToSentry()
                reply(nil, error.localizedDescription)
            }
        }
    }
    
    
    @objc func downloadFolderBackup(
        downloadAt downloadAtURL: String,
        networkAuth: String,
        folderId: String,
        bucketId: String,
        folderName: String,
        with reply: @escaping (_ result: String?, _ error: String?) -> Void
    ) {
        let downloadAtURL = URL(fileURLWithPath: downloadAtURL)

        let configManager = BackupConfigurationManager(groupName: INTERNXT_GROUP_NAME, clientName: CLIENT_NAME)
       
        guard let (backupAPI, driveNewAPI, networkFacade) = configManager.setupAPIs(networkAuth: networkAuth) else {
            reply(nil, "Setup failed")
            return
        }
        

        self.downloadOperationQueue.maxConcurrentOperationCount = 10
        
        let backupDownloadService = BackupDownloadService(
            downloadOperationQueue: downloadOperationQueue,
            backupAPI: backupAPI,
            driveNewAPI: driveNewAPI,
            networkFacade: networkFacade,
            encryptedContentURL: FileManager.default.temporaryDirectory,
            decrypt: Decrypt(),
            backupBucket: bucketId,
            backupDownloadProgress: backupDownloadProgress
        )
        Task {
            do {
                try await backupDownloadService.downloadFolderBackup(folderId: folderId, downloadAtPath: downloadAtURL, folderName: folderName)
                self.downloadOperationQueue.addBarrierBlock {
                    logger.info("Download operations completed")
                    reply(nil, nil)
                }
                
                
            } catch {
                logger.error(["Failed to download folder backup", error])
                error.reportToSentry()
                reply(nil, error.localizedDescription)
            }
        }
    }

    @objc func stopBackupUpload() {
        logger.debug("STOP BACKUP UPLOAD")
        trees = []
        
        self.backupUploadStatus = .Stopped
        self.uploadOperationQueue.cancelAllOperations()
        backupUploadService?.stopSync()
    }
    
    @objc func stopBackupDownload() {
        logger.debug("STOP BACKUP DOWNLOAD")
        self.backupDownloadStatus = .Stopped
        self.downloadOperationQueue.cancelAllOperations()
    }
    
    
    
    func getBackupUploadStatus(with reply: @escaping (BackupProgressUpdate?, String?) -> Void) {
        reply(BackupProgressUpdate(status: self.backupUploadStatus, progress: backupUploadProgress), nil)
    }
    
    func getBackupDownloadStatus(with reply: @escaping (BackupProgressUpdate?, String?) -> Void) {
        reply(BackupProgressUpdate(status: self.backupDownloadStatus, progress: backupDownloadProgress), nil)
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
    
    @objc func downloadFileBackup(downloadAt downloadAtURL: String, networkAuth: String, fileId: String, bucketId: String, with reply: @escaping (String?, String?) -> Void) {
        

        let downloadAtURL = URL(fileURLWithPath: downloadAtURL)
        
        let configManager = BackupConfigurationManager(groupName: INTERNXT_GROUP_NAME, clientName: CLIENT_NAME)
        
        guard let (backupAPI, driveNewAPI, networkFacade) = configManager.setupAPIs(networkAuth: networkAuth) else {
            reply(nil, "Setup failed")
            return
        }
        self.downloadOperationQueue.maxConcurrentOperationCount = 10
        
        let backupDownloadService = BackupDownloadService(
            downloadOperationQueue: downloadOperationQueue,
            backupAPI: backupAPI,
            driveNewAPI: driveNewAPI,
            networkFacade: networkFacade,
            encryptedContentURL: FileManager.default.temporaryDirectory,
            decrypt: Decrypt(),
            backupBucket: bucketId,
            backupDownloadProgress: backupDownloadProgress
        )
        Task {
            
            backupDownloadService.downloadFile(fileId: fileId, bucketId: bucketId, downloadAt: downloadAtURL)
            self.downloadOperationQueue.addBarrierBlock {
                logger.info("Download operations completed")
                reply(nil, nil)
            }
            reply(nil,nil)
        }
    }
    
}
