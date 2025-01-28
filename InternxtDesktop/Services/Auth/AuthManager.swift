//
//  AuthManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/8/23.
//

import Foundation
import InternxtSwiftCore
import os.log
import ObjectivePGP

struct NeedsTokenRefreshResult {
    var needsRefresh: Bool
    var authTokenCreationDate: Date
    var legacyAuthTokenCreationDate: Date
    var authTokenDaysUntilExpiration: Int
    var legacyAuthTokenDaysUntilExpiration: Int
}
class AuthManager: ObservableObject {
    let logger = Logger(subsystem: "com.internxt", category: "AuthManager")
    @Published public var isLoggedIn = false
    @Published public var user: DriveUser? = nil
    @Published public var availableWorkspaces: [AvailableWorkspace]? = []
    @Published public var workspaceCredentials: WorkspaceCredentialsResponse? = nil

    public let config = ConfigLoader()
    public let cryptoUtils = CryptoUtils()
    private let REFRESH_TOKEN_DEADLINE = 5
    init() {
        self.isLoggedIn = checkIsLoggedIn()
        self.user = config.getUser()
        self.availableWorkspaces = config.getWorkspaces()
        self.workspaceCredentials = config.getWorkspaceCredentials()
    }
    
    public var mnemonic: String? {
        return config.getMnemonic()
    }
    
    public var workspaceMnemonic: String? {
        return config.getWorkspaceMnemonic()
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
        guard let legacyAuthToken = config.getLegacyAuthToken() else {
            throw AuthError.LegacyAuthTokenNotInConfig
        }
        let refreshUserResponse = try await APIFactory.Drive.refreshUser(currentAuthToken: legacyAuthToken)
        ErrorUtils.identify(
            email:refreshUserResponse.user.email,
            uuid: refreshUserResponse.user.uuid
        )
        try config.setUser(user: refreshUserResponse.user)
        let workspaces =  try await APIFactory.DriveNew.getAvailableWorkspaces()
        try config.setAvailableWorkspaces(workspaces: workspaces.availableWorkspaces)
        if !workspaces.availableWorkspaces.isEmpty{
            let credentials = try await APIFactory.DriveNew.getCredentialsWorkspaces(workspaceId: workspaces.availableWorkspaces[0].workspaceUser.workspaceId)
                try config.setWorkspaceCredentials(credentials: credentials)
            saveWorkspaceMnemonic(key: workspaces.availableWorkspaces[0].workspaceUser.key)
            DispatchQueue.main.async{ self.workspaceCredentials = credentials}
        }
        DispatchQueue.main.async{
            self.user = refreshUserResponse.user
            self.availableWorkspaces = workspaces.availableWorkspaces
        }
        
       
        
    }
    
    func refreshTokens() async throws {
        guard let authToken = config.getAuthToken() else {
            throw AuthError.AuthTokenNotInConfig
        }
        
        let newTokensResponse = try await APIFactory.DriveNew.refreshTokens(currentAuthToken: authToken )
        
        
        try config.setLegacyAuthToken(legacyAuthToken: newTokensResponse.token)
        try config.setAuthToken(authToken: newTokensResponse.newToken)
    }
    
    func storeAuthDetails(plainMnemonic: String, authToken: String, legacyAuthToken: String,privateKey: String) throws {
        
        try config.setAuthToken(authToken: authToken)
        try config.setLegacyAuthToken(legacyAuthToken: legacyAuthToken)
        try config.setMnemonic(mnemonic: plainMnemonic)
        try config.setPrivateKey(privateKey: privateKey)
        isLoggedIn = true
        self.logger.info("Auth details stored correctly, user is logged in")
    }
    
    func signOut() throws {
        
        try config.removeAuthToken()
        try config.removeLegacyAuthToken()
        try config.removeMnemonic()
        try config.removeWorkspaces()
        try config.removeWorkspaceCredentials()
        try config.removeWorkspaceMnemonicInfo()
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
        
        guard let base64PrivateKey = components.queryItems?.first(where: { $0.name == "privateKey" })?.value else {
            self.logger.info("privateKey not found")
            return false
        }
        guard let decodedprivateKey = Data(base64Encoded: base64PrivateKey.data(using: .utf8)!) else {
            self.logger.info("Cannot decode privateKey")
            return false
        }
        
        let plainMnemonic = String(data: decodedMnemonic, encoding: .utf8)!
        let validMnemonic = cryptoUtils.validate(mnemonic: plainMnemonic)
        let plainBase64PrivateKey = String(data: decodedprivateKey, encoding: .utf8)!
        
        if validMnemonic == false {
            self.logger.info("The decoded mnemonic is not valid")
            return false
        }
        try self.storeAuthDetails(
            plainMnemonic: plainMnemonic,
            authToken: config.get().AUTH_TOKEN ?? String(data: decodedToken, encoding: .utf8)!,
            legacyAuthToken: config.get().LEGACY_AUTH_TOKEN ?? String(data: decodedLegacyToken, encoding: .utf8)!, privateKey: plainBase64PrivateKey
        )
        
        return true
    }
    
    
    func needRefreshToken() throws -> NeedsTokenRefreshResult {
        guard let legacyAuthToken = config.getLegacyAuthToken() else {
            throw AuthError.LegacyAuthTokenNotInConfig
        }
        
        guard let authToken = config.getAuthToken() else {
            throw AuthError.AuthTokenNotInConfig
        }

        let decodedLegacyAuthToken = try JWTDecoder.decode(jwtToken: legacyAuthToken)
        let decodedAuthToken = try JWTDecoder.decode(jwtToken: authToken)
        
        guard let authTokenExpirationTimestamp = decodedAuthToken["exp"] as? Int else {
            throw AuthError.InvalidTokenExp
        }
        
        guard let authTokenCreationTimestamp = decodedAuthToken["iat"] as? Int else {
            throw AuthError.InvalidTokenIat
        }
        
        
        guard let legacyAuthTokenExpirationTimestamp = decodedLegacyAuthToken["exp"] as? Int else {
            throw AuthError.InvalidTokenExp
        }
        
        guard let legacyAuthTokenCreationTimestamp = decodedLegacyAuthToken["iat"] as? Int else {
            throw AuthError.InvalidTokenIat
        }
        
        let authTokenExpirationDate = Date(timeIntervalSince1970: TimeInterval(authTokenExpirationTimestamp))
        let authTokenCreationDate = Date(timeIntervalSince1970: TimeInterval(authTokenCreationTimestamp))
        
        let legacyAuthTokenExpirationDate = Date(timeIntervalSince1970: TimeInterval(legacyAuthTokenExpirationTimestamp))
        let legacyAuthTokenCreationDate = Date(timeIntervalSince1970: TimeInterval(legacyAuthTokenCreationTimestamp))
        
        
        
        let daysUntilAuthTokenExpires = Date().daysUntil(authTokenExpirationDate) ?? 1
        let daysUntilLegacyAuthTokenExpires = Date().daysUntil(legacyAuthTokenExpirationDate) ?? 1
        
        if daysUntilAuthTokenExpires <= REFRESH_TOKEN_DEADLINE {
            return NeedsTokenRefreshResult(
                needsRefresh: true,
                authTokenCreationDate: authTokenCreationDate,
                legacyAuthTokenCreationDate:legacyAuthTokenCreationDate,
                authTokenDaysUntilExpiration: daysUntilAuthTokenExpires,
                legacyAuthTokenDaysUntilExpiration: daysUntilLegacyAuthTokenExpires
            )
        }
        
        if daysUntilLegacyAuthTokenExpires <= REFRESH_TOKEN_DEADLINE {
            return NeedsTokenRefreshResult(
                needsRefresh: true,
                authTokenCreationDate: authTokenCreationDate,
                legacyAuthTokenCreationDate:legacyAuthTokenCreationDate,
                authTokenDaysUntilExpiration: daysUntilAuthTokenExpires,
                legacyAuthTokenDaysUntilExpiration: daysUntilLegacyAuthTokenExpires
            )
        }

        
        
        return NeedsTokenRefreshResult(
            needsRefresh: false,
            authTokenCreationDate: authTokenCreationDate,
            legacyAuthTokenCreationDate:legacyAuthTokenCreationDate,
            authTokenDaysUntilExpiration: daysUntilAuthTokenExpires,
            legacyAuthTokenDaysUntilExpiration: daysUntilLegacyAuthTokenExpires
        )
    }
    
    private func saveWorkspaceMnemonic(key: String){
        do {
            guard let privateKey = config.getPrivateKey() else {
                self.logger.info("Cannot get privateKey")
                return
            }
            let mnemonic =  try decryptMessageWithPrivateKey(encryptedMessageBase64: key, privateKeyBase64: privateKey)
            
            let validMnemonicWorkspace = cryptoUtils.validate(mnemonic: mnemonic)
            if !validMnemonicWorkspace {
                self.logger.error("The decoded Workspace mnemonic is not valid")
                return
            }
            try config.setWorkspaceMnemonic(workspaceMnemonic: mnemonic)
        }catch {
            self.logger.error("Failed to decrypt message: \(error.localizedDescription)")
            
        }
        
    }
    
    func decryptMessageWithPrivateKey(
        encryptedMessageBase64: String,
        privateKeyBase64: String
    ) throws -> String {
       
        guard let privateKeyData = Data(base64Encoded: privateKeyBase64) else {
            throw DecryptionError.invalidPrivateKey
        }
        
        let privateKeys = try ObjectivePGP.readKeys(from: privateKeyData)
 
        
        guard privateKeys.count > 0 else {
        
            throw DecryptionError.invalidEncryptedMessage
        }

        guard let encryptedMessageData = Data(base64Encoded: encryptedMessageBase64) else {
            throw DecryptionError.invalidEncryptedMessage
        }

        let decryptedData = try ObjectivePGP.decrypt(encryptedMessageData, andVerifySignature: false, using: privateKeys)

        guard let decryptedMessage = String(data: decryptedData, encoding: .utf8) else {
            throw DecryptionError.invalidDecryptedData
        }
        return decryptedMessage
    }
}


class AuthManagerForPreview: AuthManager {}


enum DecryptionError: Error {
    case invalidPrivateKey
    case invalidEncryptedMessage
    case invalidDecryptedData
}
