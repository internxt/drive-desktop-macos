//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation
import InternxtSwiftCore

class XPCBackupService: NSObject, XPCBackupServiceProtocol {
    @objc func startBackup(backupAt backupURL: URL, mnemonic: String, networkAuth: String?, authToken: String, deviceId: Int, bucketId: String, with reply: @escaping (_ result: String?, _ error: String?) -> Void) {

        Task {
            guard let networkAuth = networkAuth else {
                reply(nil, "Cannot get network auth")
                return
            }

            let configLoader = ConfigLoader()
            let config = configLoader.get()
            let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: CLIENT_NAME, clientVersion: getVersion())
            let backupUploadService = BackupUploadService(
                networkFacade: NetworkFacade(mnemonic: mnemonic, networkAPI: networkAPI),
                encryptedContentDirectory: FileManager.default.temporaryDirectory,
                deviceId: deviceId,
                bucketId: bucketId,
                authToken: authToken,
                backupProgress: Progress()
            )
            let backupTreeGenerator = BackupTreeGenerator(root: backupURL, backupUploadService: backupUploadService)

            let backupTree = try await backupTreeGenerator.generateTree()

            try await backupTree.syncNodes()
            
            reply("Device backed up successfully", nil)
        }
        
    }
}
