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

    @objc func startBackup(backupAt backupURLs: [String], mnemonic: String, networkAuth: String?, authToken: String, deviceId: Int, bucketId: String, with reply: @escaping (_ result: String?, _ error: String?) -> Void) {

        Task {
            guard let networkAuth = networkAuth else {
                reply(nil, "Cannot get network auth")
                return
            }

            let configLoader = ConfigLoader()
            let config = configLoader.get()
            let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: CLIENT_NAME, clientVersion: getVersion())
            let totalProgress = Progress()

            let backupUploadService = BackupUploadService(
                networkFacade: NetworkFacade(mnemonic: mnemonic, networkAPI: networkAPI),
                encryptedContentDirectory: FileManager.default.temporaryDirectory,
                deviceId: deviceId,
                bucketId: bucketId,
                authToken: authToken,
                backupProgress: totalProgress
            )

            var trees: [BackupTreeNode] = []
            for backupURL in backupURLs {
                let url = URL(fileURLWithPath: backupURL)
                let backupTreeGenerator = BackupTreeGenerator(root: url, backupUploadService: backupUploadService)

                let backupTree = try await backupTreeGenerator.generateTree()

                trees.append(backupTree)
            }

            var totalCount = 0
            for backupTree in trees {
                let count = self.getNodesCountFromURL(backupTree: backupTree)
                totalCount += count
            }

            totalProgress.totalUnitCount = Int64(totalCount)

            for backupTree in trees {
                do {
                    try await backupTree.syncNodes(progress: totalProgress)
                } catch {
                    reply(nil, error.localizedDescription)
                }
            }

            reply("synced all nodes for all trees", nil)

        }

    }

    private func getNodesCountFromURL(backupTree: BackupTreeNode) -> Int {
        var count = 0
        if let url = backupTree.url, let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey], options: [.skipsHiddenFiles]) {
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
