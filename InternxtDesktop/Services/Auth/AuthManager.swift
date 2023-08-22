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
    
    func initializeCurrentUser() {
        Task {
            do {
                let refreshUserResponse = try await APIFactory.Drive.refreshUser()
                DispatchQueue.main.async{
                    self.user = refreshUserResponse.user
                }
            } catch {
                self.logger.error("Failed to refresh current user: \(error)")
               
                print(error)
                if error is APIClientError {
                    let apiError = (error as! APIClientError)
                    let body = String(data:(error as! APIClientError).responseBody, encoding: .utf8)
                    self.logger.error("Refresh current user response: \(body!)")
                }
                
                
            }
            
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
        
        isLoggedIn = false
        self.logger.info("Auth details removed correctly, user is logged out")
    }
    
}


class AuthManagerForPreview: AuthManager {}
