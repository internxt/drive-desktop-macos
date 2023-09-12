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
    
}


class AuthManagerForPreview: AuthManager {}
