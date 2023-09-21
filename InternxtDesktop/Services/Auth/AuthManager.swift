//
//  AuthManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/8/23.
//

import Foundation
import InternxtSwiftCore
import os.log

class AuthManager: ObservableObject {
    let logger = Logger(subsystem: "com.internxt", category: "AuthManager")
    @Published public var isLoggedIn = false
    @Published public var user: DriveUser? = nil
    public let config = ConfigLoader()
    public let cryptoUtils = CryptoUtils()
    init() {
        self.isLoggedIn = checkIsLoggedIn()
        self.user = config.getUser()
    }
    
    public var mnemonic: String? {
        return config.getMnemonic()
    }
    
    func checkIsLoggedIn() -> Bool {
        guard config.getAuthToken() != nil else {
            return false
        }
        
        guard config.getMnemonic() != nil else {
            return false
        }
        
        guard config.getLegacyAuthToken() != nil else {
            return false
        }
        
        return true
    }
    
    func initializeCurrentUser() async throws {
        let refreshUserResponse = try await APIFactory.Drive.refreshUser()
        ErrorUtils.identify(
            email:refreshUserResponse.user.email,
            uuid: refreshUserResponse.user.uuid
        )
        try config.setUser(user: refreshUserResponse.user)
        
        DispatchQueue.main.async{
            self.user = refreshUserResponse.user
        }
    }
    
    func storeAuthDetails(plainMnemonic: String, authToken: String, legacyAuthToken: String) throws {
        
        try config.setAuthToken(authToken: authToken)
        try config.setLegacyAuthToken(legacyAuthToken: legacyAuthToken)
        try config.setMnemonic(mnemonic: plainMnemonic)
        
        isLoggedIn = true
        self.logger.info("Auth details stored correctly, user is logged in")
    }
    
    func signOut() throws {
        
        try config.removeAuthToken()
        try config.removeLegacyAuthToken()
        try config.removeMnemonic()
        user = nil
        ErrorUtils.clean()
        isLoggedIn = false
        self.logger.info("Auth details removed correctly, user is logged out")
    }
    
    func handleSignInDeeplink(url: URL) throws -> Bool {
        guard url.scheme == "internxt" else {
            self.logger.info("Invalid scheme")
            return false
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            self.logger.info("Invalid URL")
            return false
        }
        
        guard let action = components.host, action == "login-success" else {
            self.logger.info("Unknown URL, not handling")
            return false
        }
        
        guard let base64Mnemonic = components.queryItems?.first(where: { $0.name == "mnemonic" })?.value else {
            self.logger.info("Mnemonic not found")
            return false
        }
        
        
        guard let base64LegacyToken = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            self.logger.info("Legacy token not found")
            return false
        }
        
        guard let base64Token = components.queryItems?.first(where: { $0.name == "newToken" })?.value else {
            self.logger.info("Token not found")
            return false
        }
        
        guard let decodedToken = Data(base64Encoded: base64Token.data(using: .utf8)!) else {
            self.logger.info("Cannot decode token")
            return false
        }
        
        guard let decodedLegacyToken = Data(base64Encoded: base64LegacyToken.data(using: .utf8)!) else {
            self.logger.info("Cannot decode legacy token")
            return false
        }
        
        guard let decodedMnemonic = Data(base64Encoded: base64Mnemonic.data(using: .utf8)!) else {
            self.logger.info("Cannot decode mnemonic")
            return false
        }
        
        let plainMnemonic = String(data: decodedMnemonic, encoding: .utf8)!
        let validMnemonic = cryptoUtils.validate(mnemonic: plainMnemonic)
        
        if validMnemonic == false {
            self.logger.info("The decoded mnemonic is not valid")
            return false
        }
        try self.storeAuthDetails(
            plainMnemonic: plainMnemonic,
            authToken: config.get().AUTH_TOKEN ?? String(data: decodedToken, encoding: .utf8)!,
            legacyAuthToken: config.get().LEGACY_AUTH_TOKEN ?? String(data: decodedLegacyToken, encoding: .utf8)!
        )
        
        return true
    }
    
}


class AuthManagerForPreview: AuthManager {}
