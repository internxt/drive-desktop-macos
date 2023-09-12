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
}

enum ConfigLoaderError: Error {
    case ConfigFileDoesntExists
    case CannotSaveAuthToken
    case CannotRetrieveAuthToken
    case CannotSaveMnemonic
    case CannotRemoveKey
    case CannotSaveUser
    case CannotRemoveUser
}

public var loadedConfig: JSONConfig? = nil
public var loadedLegacyAuthToken: String? = nil
public var loadedAuthToken: String? = nil
public struct ConfigLoader {
    
    // We hardcode this value, so no other team can sign with our teamID, this corresponds to our Apps Groups
    private let SUITE_NAME = "JR4S3SY396.group.internxt.desktop"
    public init() {
        
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
    
    public func getLegacyAuthToken() -> String? {
        return self.getFromUserDefaults(key: "LegacyAuthToken")
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
    
    public func setLegacyAuthToken(legacyAuthToken: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "LegacyAuthToken", value: legacyAuthToken)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveAuthToken
        }
    }
    
    public func removeLegacyAuthToken() throws -> Void  {
        let removed = self.removeFromUserDefaults(key: "LegacyAuthToken")
        
        if removed == false {
            throw ConfigLoaderError.CannotRemoveKey
        }
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
}


