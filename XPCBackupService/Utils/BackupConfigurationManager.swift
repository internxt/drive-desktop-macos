//
//  BackupConfigurationManager.swift
//  XPCBackupService
//
//  Created by Patricio Tovar on 6/8/24.
//

import Foundation
import InternxtSwiftCore

class BackupConfigurationManager {
    private let groupName: String
    private let clientName: String
    private let MNEMONIC_TOKEN_KEY = "Mnemonic"
    private let AUTH_TOKEN_KEY = "AuthToken"
    
    init(groupName: String, clientName: String) {
        self.groupName = groupName
        self.clientName = clientName
    }

    private func setupSharedDefaults() -> UserDefaults? {
        guard let sharedDefaults = UserDefaults(suiteName: groupName) else {
            logger.error("Cannot get sharedDefaults")
            return nil
        }
        return sharedDefaults
    }

    func getAuthToken() -> String? {
        guard let sharedDefaults = setupSharedDefaults(),
              let newAuthToken = sharedDefaults.string(forKey: AUTH_TOKEN_KEY) else {
            logger.error("Cannot get AuthToken")
            return nil
        }
        return newAuthToken
    }

    func getMnemonic() -> String? {
        guard let sharedDefaults = setupSharedDefaults(),
              let mnemonic = sharedDefaults.string(forKey: MNEMONIC_TOKEN_KEY) else {
            logger.error("Cannot get mnemonic")
            return nil
        }
        return mnemonic
    }
    
    func setupAPIs(networkAuth: String) -> (BackupAPI, DriveAPI, NetworkFacade)? {
        guard let authToken = getAuthToken() else {
            logger.error("Cannot get AuthToken")
            return nil
        }
        
        let config = ConfigLoader().get()
        let backupAPI = BackupAPI(baseUrl: config.DRIVE_NEW_API_URL, authToken: authToken, clientName: clientName, clientVersion: getVersion())
        let driveNewAPI = DriveAPI(baseUrl: config.DRIVE_NEW_API_URL, authToken: authToken, clientName: clientName, clientVersion: getVersion())
        let networkAPI = NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: networkAuth, clientName: clientName, clientVersion: getVersion())
        
        guard let mnemonic = getMnemonic() else { return nil }
        let networkFacade = NetworkFacade(mnemonic: mnemonic, networkAPI: networkAPI, debug: true)
        return (backupAPI, driveNewAPI, networkFacade)
    }
}
