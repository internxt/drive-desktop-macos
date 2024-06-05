// Integration tests for SwiftKyber
import XCTest

class SwiftKyberIntegrationTests: XCTestCase {
    func testEncryptDecryptCycle() {
        let keyManager = KyberKeyManager()
        keyManager.generateKeys()

        guard let publicKey = keyManager.getPublicKey(),
              let privateKey = keyManager.getPrivateKey() else {
            XCTFail("Keys should not be nil")
            return
        }

        let encryptor = KyberEncryptor()
        let decryptor = KyberDecryptor()

        let originalMessage = "Integration test message"
        guard let encryptedData = encryptor.encrypt(data: originalMessage.data(using: .utf8)!, withPublicKey: publicKey) else {
            XCTFail("Encryption failed")
            return
        }

        guard let decryptedData = decryptor.decrypt(data: encryptedData, withPrivateKey: privateKey),
              let decryptedMessage = String(data: decryptedData, encoding: .utf8) else {
            XCTFail("Decryption failed")
            return
        }

        XCTAssertEqual(originalMessage, decryptedMessage, "Decrypted message should match the original")
    }
}
