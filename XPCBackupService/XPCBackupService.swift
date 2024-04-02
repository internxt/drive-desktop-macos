//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation
import InternxtSwiftCore

public class XPCBackupService: NSObject, XPCBackupServiceProtocol {

    public static let shared = XPCBackupService()
    private var backupUploadService: BackupUploadService? = nil
    private var trees: [BackupTreeNode] = []
    private let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "App")

    @objc func startBackup(backupAt backupURLs: [String], mnemonic: String, networkAuth: String?, authToken: String, newAuthToken: String, deviceId: Int, bucketId: String, with reply: @escaping (_ result: String?, _ error: String?) -> Void) {
        logger.info("Start backup")
        logger.info("Going to backup folders: \(backupURLs)")
        Task {
            guard let networkAuth = networkAuth else {
                reply(nil, "Cannot get network auth")
                return
            }

            let configLoader = ConfigLoader()
            let config = configLoader.get()
            let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: CLIENT_NAME, clientVersion: getVersion())
            let progress = Progress()

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

            var totalCount = 0
            for backupURL in backupURLs {
                let count = self.getNodesCountFromURL(URL(fileURLWithPath: backupURL.removingPercentEncoding ?? ""))
                totalCount = totalCount + count
            }

            logger.info("Total progress to backup \(totalCount)")

            progress.totalUnitCount = Int64(totalCount)

            for backupURL in backupURLs {
                let backupTreeGenerator = BackupTreeGenerator(root: URL(fileURLWithPath: backupURL.removingPercentEncoding ?? ""), backupUploadService: backupUploadService, progress: progress)

                let backupTree = try await backupTreeGenerator.generateTree()
                logger.info("Backup tree created successfully")

                trees.append(backupTree)
            }

            for backupTree in trees {
                do {
                    try await backupTree.syncNodes()
                } catch {
                    logger.error("Error backing up device \(error)")
                    reply(nil, error.localizedDescription)
                }
            }

            reply("synced all nodes for all trees", nil)

        }

    }

    @objc func stopBackup() {
        logger.debug("STOP BACKUP")
        trees = []
        backupUploadService?.stopSync()
    }

    private func getNodesCountFromURL(_ url: URL) -> Int {
        // we start in one so we can count the tree root
        var count = 1
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
