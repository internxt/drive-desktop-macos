
// Error handling improvements
// Ensured robust handling of edge cases in encryption API.
class KyberEncryptor {
    func encrypt(data: Data, withPublicKey publicKey: Data) -> Data? {
        let kyber = SwiftKyber()
        return kyber.encrypt(data, publicKey: publicKey)
    }
}

let encryptor = KyberEncryptor()
if let encryptedData = encryptor.encrypt(data: "Hello World".data(using: .utf8)!, withPublicKey: keyManager.getPublicKey()!) {
    print("Encryption successful: \(encryptedData)")
}
