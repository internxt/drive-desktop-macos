// Added benchmarking tests for key generation performance.
import XCTest

class SwiftKyberBenchmarkTests: XCTestCase {
    func testKeyGenerationPerformance() {
        measure {
            let keyManager = KyberKeyManager()
            keyManager.generateKeys()
        }
    }
}

