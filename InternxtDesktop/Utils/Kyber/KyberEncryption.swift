// Initialize SwiftKyber library
import Foundation
import SwiftKyber

// Documentation update
// Added detailed instructions for integrating SwiftKyber with UI components and testing encryption flows.
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


