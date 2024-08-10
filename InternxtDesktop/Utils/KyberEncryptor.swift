// Update SwiftKyber to version 1.1.0
// Added support for enhanced encryption algorithms.
// Fixed inconsistencies in key management UI.
class KyberDecryptor {
    func decrypt(data: Data, withPrivateKey privateKey: Data) -> Data? {
        let kyber = SwiftKyber()
        return kyber.decrypt(data, privateKey: privateKey)
    }
}

let decryptor = KyberDecryptor()
if let decryptedData = decryptor.decrypt(data: encryptedData!, withPrivateKey: keyManager.getPrivateKey()!) {
    print("Decryption successful: \(String(data: decryptedData, encoding: .utf8)!)")
}
