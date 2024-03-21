//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation
import os.log
import InternxtSwiftCore

public class XPCBackupService: NSObject, XPCBackupServiceProtocol {

    public static let shared = XPCBackupService()
    private let logger = Logger(subsystem: "com.internxt", category: "XPCBackupService")

    @objc func startBackup(backupAt backupURLs: [String], mnemonic: String, networkAuth: String?, authToken: String, newAuthToken: String, deviceId: Int, bucketId: String, with reply: @escaping (_ result: String?, _ error: String?) -> Void) {

        Task {
            guard let networkAuth = networkAuth else {
                reply(nil, "Cannot get network auth")
                return
            }

            let configLoader = ConfigLoader()
            let config = configLoader.get()
            let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: CLIENT_NAME, clientVersion: getVersion())
            let progress = Progress()

            let backupUploadService = BackupUploadService(
                networkFacade: NetworkFacade(mnemonic: mnemonic, networkAPI: networkAPI),
                encryptedContentDirectory: FileManager.default.temporaryDirectory,
                deviceId: deviceId,
                bucketId: bucketId,
                authToken: authToken,
                newAuthToken: newAuthToken,
                backupClient: BackupClient.shared
            )

            var totalCount = 0
            for backupURL in backupURLs {
                let count = self.getNodesCountFromURL(URL(fileURLWithPath: backupURL))
                totalCount += count
            }

            progress.totalUnitCount = Int64(totalCount)

            var trees: [BackupTreeNode] = []
            for backupURL in backupURLs {
                let url = URL(fileURLWithPath: backupURL)
                let backupTreeGenerator = BackupTreeGenerator(root: url, backupUploadService: backupUploadService, progress: progress)

                let backupTree = try await backupTreeGenerator.generateTree()

                trees.append(backupTree)
            }

            logger.info("Total progress to backup \(progress.totalUnitCount)")

            for backupTree in trees {
                do {
                    try await backupTree.syncNodes()
                } catch {
                    reply(nil, error.localizedDescription)
                }
            }

            reply("synced all nodes for all trees", nil)

        }

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
