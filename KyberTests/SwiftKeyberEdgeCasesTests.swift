// Added tests for edge cases in encryption
import XCTest

class SwiftKyberEdgeTests: XCTestCase {
    func testEmptyMessageEncryption() {
        let keyManager = KyberKeyManager()
        keyManager.generateKeys()
        let encryptor = KyberEncryptor()

        guard let publicKey = keyManager.getPublicKey() else {
            XCTFail("Public key should not be nil")
            return
        }

        let encryptedData = encryptor.encrypt(data: Data(), withPublicKey: publicKey)
        XCTAssertNotNil(encryptedData, "Encryption of an empty message should succeed")
    }
}
