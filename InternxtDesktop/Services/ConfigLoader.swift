//
//  ConfigLoader.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import Foundation
import Security


public struct JSONConfig: Codable {
    public let MNEMONIC: String
    public let ROOT_FOLDER_ID: String
    public let LEGACY_AUTH_TOKEN: String?
    public let AUTH_TOKEN: String?
    public let DRIVE_API_URL: String
    public let NETWORK_API_URL: String
    public let NETWORK_AUTH: String
    public let DRIVE_NEW_API_URL: String
    public let BUCKET_ID: String
    public let MAGIC_IV_HEX: String
    public let MAGIC_SALT_HEX: String
    public let CRYPTO_SECRET2: String
}

enum ConfigLoaderError: Error {
    case ConfigFileDoesntExists
    case CannotSaveAuthToken
    case CannotRetrieveAuthToken
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
    
    public func setLegacyAuthToken(legacyAuthToken: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "LegacyAuthToken", value: legacyAuthToken)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveAuthToken
        }
    }
    
    public func setAuthToken(authToken: String) throws -> Void {
        let saved = self.saveToUserDefaults(key: "AuthToken", value: authToken)
        
        if saved == false {
            throw ConfigLoaderError.CannotSaveAuthToken
        }
    }
    
    public func get() -> JSONConfig {
        if(loadedConfig == nil) {
            self.load()
        }
        return loadedConfig!
    }
    
    private func saveToUserDefaults(key: String, value: String) -> Bool {
        
        guard let defaults = UserDefaults(suiteName: SUITE_NAME) else {
            return false
        }
            
        defaults.set(value, forKey: key)
        return true
    }
    
    private func getFromUserDefaults(key: String) -> String? {
        guard let defaults = UserDefaults(suiteName:SUITE_NAME) else {
            return nil
        }
        
        return defaults.string(forKey: key)
    }
}


