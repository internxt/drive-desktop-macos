// Decryption using SwiftKyber
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
