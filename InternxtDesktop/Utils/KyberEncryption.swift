//
//  KyberEncryption.swift
//  InternxtDesktop
//
//  Created by Roberto García on 15/01/24.
//

// Initialize SwiftKyber library
import Foundation
import SwiftKyber

// Optimization
// Refactored KyberKeyManager for performance improvements and modularity.
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

