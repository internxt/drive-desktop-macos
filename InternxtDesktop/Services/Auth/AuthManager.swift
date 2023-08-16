//
//  AuthManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/8/23.
//

import Foundation


class AuthManager: ObservableObject {
    @Published public var isLoggedIn = false
    
    func signIn() {
        isLoggedIn = true
    }
    
    func signOut() {
        isLoggedIn = false
    }
    
}


class AuthManagerForPreview: AuthManager {}
