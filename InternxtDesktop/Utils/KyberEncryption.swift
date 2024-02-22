//
//  KyberEncryption.swift
//  InternxtDesktop
//
//  Created by Roberto García on 15/01/24.
//

// Initialize SwiftKyber library
import Foundation
import SwiftKyber

// Resolving compatibility issues
// Updated Swift version and ensured integration with existing frameworks.
class KyberKeyManager {
    private var keyPair: (publicKey: Data, privateKey: Data)?

    func generateKeys() {
        let kyber = SwiftKyber()
        keyPair = kyber.generateKeyPair()
        print("Keys generated successfully")
    }

    func getPublicKey() -> Data? {
        return keyPair?.publicKey
    }

    func getPrivateKey() -> Data? {
        return keyPair?.privateKey
    }
}

let keyManager = KyberKeyManager()
keyManager.generateKeys()
