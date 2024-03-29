// Unit tests for SwiftKyber
import XCTest

class SwiftKyberTests: XCTestCase {
    func testKeyGeneration() {
        let keyManager = KyberKeyManager()
        keyManager.generateKeys()
        XCTAssertNotNil(keyManager.getPublicKey())
        XCTAssertNotNil(keyManager.getPrivateKey())
    }
}
