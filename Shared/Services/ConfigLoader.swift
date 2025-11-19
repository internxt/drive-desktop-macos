//
//  ConfigLoader.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import Foundation
import Security
import InternxtSwiftCore
import CryptoKit

public struct JSONConfig: Codable {
    public let DRIVE_API_URL: String
    public let NETWORK_API_URL: String
    public let DRIVE_NEW_API_URL: String
    public let PHOTOS_API_URL: String
    public let MAGIC_IV_HEX: String
    public let MAGIC_SALT_HEX: String
    public let CRYPTO_SECRET2: String
    public let SENTRY_DSN: String
    public let NOTIFICATIONS_URL: String
    public let RUDDERSTACK_WRITE_KEY: String
    public let RUDDERSTACK_DATA_PLANE_URL: String
    public let LEGACY_AUTH_TOKEN: String?
    public let AUTH_TOKEN: String?
    public let GATEWAY_API_URL: String
    public let HEADER_KEY_GATEWAY: String
}

enum ConfigLoaderError: Error {
    case ConfigFileDoesntExists
    case CannotSaveAuthToken
    case CannotRetrieveAuthToken
    case CannotSaveMnemonic
    case CannotRemoveKey
    case CannotSaveUser
    case CannotRemoveUser
    case CannotSaveOnboardingIsCompleted
    case CannotHideBackupBanner
    case CannotSaveWorkspaces
    case CannotSaveWorkspacesCredentials
    case CannotSavePrivateKey
    case CannotSaveWorkspaceMnemonic
}


public let INTERNXT_GROUP_NAME = "JR4S3SY396.group.internxt.desktop"

public var loadedConfig: JSONConfig? = nil

public struct ConfigLoader {
    static let shared: ConfigLoader = ConfigLoader()
    
    
    // We hardcode this value, so no other team can sign with our teamID, this corresponds to our Apps Groups
    static let realmURL: URL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: INTERNXT_GROUP_NAME)!.appendingPathComponent("internxt_desktop.realm")
    private let SUITE_NAME = INTERNXT_GROUP_NAME
    public init() {
        
    }
    
    static var isDevMode: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }
    
    static var isReleaseMode: Bool {
        !ConfigLoader.isDevMode
    }
    
   
    
    public static func build() -> ConfigLoader {
        return ConfigLoader()
    }
    
    public func load() -> Void {
        
        do {
            guard let filePath: String = Bundle.main.path(forResource: "env.local", ofType: "json") else {
                fatalError("Env file was not found, unable to run the app")
            }
            
            let fileUrl = URL(fileURLWithPath: filePath)
            let data = try Data(contentsOf: fileUrl)
            
            let decodedData = try JSONDecoder().decode(JSONConfig.self, from: data)
            loadedConfig = decodedData
        } catch {
            print(error)
            fatalError(error.localizedDescription)
        }
        
    }
    
    
    public func getAuthToken() -> String? {
        return self.getFromUserDefaults(key: "AuthToken")
    }
    
    public func getMnemonic() -> String? {
        return self.getFromUserDefaults(key: "Mnemonic")
    }

    public func getNetworkAuth() -> String? {
        guard let user = getUser() else {
            return nil
        }
        var hasher = SHA256()
        
        hasher.update(data: user.userId.data(using: .utf8)!)
        
        let digest = hasher.finalize()
        var result = [UInt8]()
        digest.withUnsafeBytes {bytes in
            result.append(contentsOf: bytes)
        }
        
        let userAndPass = "\(user.bridgeUser):\(CryptoUtils().bytesToHexString(result))"
        return userAndPass.data(using: .utf8)?.base64EncodedString()
    }
    

    public func getNetworkAuthWorkspace() -> String? {
        
        guard let credentials = getWorkspaceCredentials() else {
            return nil
        }
        var hasher = SHA256()
        
        hasher.update(data: credentials.credentials.networkPass.data(using: .utf8)!)
        
        let digest = hasher.finalize()
        var result = [UInt8]()
        digest.withUnsafeBytes {bytes in
            result.append(contentsOf: bytes)
        }
        let userAndPass = "\(credentials.credentials.networkUser):\(CryptoUtils().bytesToHexString(result))"
        return userAndPass.data(using: .utf8)?.base64EncodedString()
    }
    public func getUser() -> DriveUser? {
        let userStr = self.getFromUserDefaults(key: "DriveUser")
        guard let userData = userStr?.data(using: .utf8) else {
            return nil
        }
        do {
            let jsonData = try JSONDecoder().decode(DriveUser.self, from: userData)
            return jsonData
        } catch {
            print(error)
            return nil
        }
        
        
        
    }
    

    
    public func removeLegacyAuthToken() -> Void  {
        let removed = self.removeFromUserDefaults(key: "LegacyAuthToken")
        //keep to remove value
    }
    
    public func setMnemonic(mnemonic: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "Mnemonic", value: mnemonic)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveMnemonic
        }
    }
    
    public func removeMnemonic() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "Mnemonic")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
    
    public func setAuthToken(authToken: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "AuthToken", value: authToken)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveAuthToken
        }
    }
    
    public func removeAuthToken() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "AuthToken")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
    
    public func setUser(user: DriveUser) throws -> Void {
        let jsonData = try JSONEncoder().encode(user)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ConfigLoaderError.CannotSaveUser
        }
        
        let saved = self.saveToUserDefaults(key: "DriveUser", value: jsonString)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveUser
        }
    }
    
    public func completeOnboarding() throws -> Void {
        let saved = self.saveToUserDefaults(key: "OnboardingIsCompleted", value: "1")
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveOnboardingIsCompleted
        }
    }

    public func shouldDisplayBackupsBanner(shouldDisplay: Bool) throws -> Void {
        let show = self.saveToUserDefaults(key: "ShowBackupBanner", value: shouldDisplay ? "1" : "0")

        if !show {
            throw ConfigLoaderError.CannotHideBackupBanner
        }
    }

    public func onboardingIsCompleted() -> Bool {
        let completed = self.getFromUserDefaults(key: "OnboardingIsCompleted")

        return completed == "1"
    }

    public func shouldShowBackupsBanner() -> Bool {
        let shouldShow = self.getFromUserDefaults(key: "ShowBackupBanner") == "1"

        return shouldShow
    }

    public func removeUser() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "DriveUser")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
    
    public func get() -> JSONConfig {
        if(loadedConfig == nil) {
            self.load()
        }
        return loadedConfig!
    }
    
    func saveToUserDefaults(key: String, value: String) -> Bool {
        
        guard let defaults = UserDefaults(suiteName: SUITE_NAME) else {
            return false
        }
        
        defaults.set(value, forKey: key)
        return true
    }
    
    func removeFromUserDefaults(key: String) -> Bool {
        
        guard let defaults = UserDefaults(suiteName: SUITE_NAME) else {
            return false
        }
        
        defaults.removeObject(forKey: key)
        return true
    }
    
    func getFromUserDefaults(key: String) -> String? {
        guard let defaults = UserDefaults(suiteName:SUITE_NAME) else {
            return nil
        }
        
        return defaults.string(forKey: key)
    }
    
    public func getDeviceName() -> String? {
        return Host.current().localizedName
    }
    
    public func setAvailableWorkspaces(workspaces: [AvailableWorkspace]) throws -> Void {
        let jsonData = try JSONEncoder().encode(workspaces)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ConfigLoaderError.CannotSaveWorkspaces
        }
        
        let saved = self.saveToUserDefaults(key: "AvailableWorkspaces", value: jsonString)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveWorkspaces
        }
    }
    
    public func getWorkspaces() -> [AvailableWorkspace]? {
        let workspaces = self.getFromUserDefaults(key: "AvailableWorkspaces")
        guard let workspacesData = workspaces?.data(using: .utf8) else {
            return nil
        }
        do {
            let jsonData = try JSONDecoder().decode([AvailableWorkspace].self, from: workspacesData)
            return jsonData
        } catch {
            print(error)
            return nil
        }
    }
    
    public func removeWorkspaces() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "AvailableWorkspaces")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
    
    public func setWorkspaceCredentials(credentials: WorkspaceCredentialsResponse) throws -> Void {
        let jsonData = try JSONEncoder().encode(credentials)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw ConfigLoaderError.CannotSaveWorkspacesCredentials
        }
        
        let saved = self.saveToUserDefaults(key: "WorkspaceCredentials", value: jsonString)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveWorkspacesCredentials
        }
    }
    
    public func getWorkspaceCredentials() -> WorkspaceCredentialsResponse? {
        let workspaces = self.getFromUserDefaults(key: "WorkspaceCredentials")
        guard let workspacesData = workspaces?.data(using: .utf8) else {
            return nil
        }
        do {
            let jsonData = try JSONDecoder().decode(WorkspaceCredentialsResponse.self, from: workspacesData)
            return jsonData
        } catch {
            print(error)
            return nil
        }
    }
    
    public func removeWorkspaceCredentials() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "WorkspaceCredentials")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
    
    public func setPrivateKey(privateKey: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "PrivateKey", value: privateKey)
        
        if saved == false {
            throw ConfigLoaderError.CannotSavePrivateKey
        }
    }
    
    public func getPrivateKey() -> String? {
        return self.getFromUserDefaults(key: "PrivateKey")
    }
    
    
    public func setWorkspaceMnemonic(workspaceMnemonic: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "WorkspaceMnemonic", value: workspaceMnemonic)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveWorkspaceMnemonic
        }
    }
    
    public func getWorkspaceMnemonic() -> String? {
        return self.getFromUserDefaults(key: "WorkspaceMnemonic")
    }
    
    public func removeWorkspaceMnemonicInfo() throws -> Void{
        let removedKey = self.removeFromUserDefaults(key: "PrivateKey")
        let removedMnemonic = self.removeFromUserDefaults(key: "WorkspaceMnemonic")

        if removedKey == false || removedMnemonic == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
    }
}


