//
//  CopyInternxtLinkUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 6/5/26.
//

import Foundation
import InternxtSwiftCore
import FileProvider
import AppKit


struct CopyInternxtLinkUseCase {

    let logger = syncExtensionLogger

   

    private let driveAPI: DriveAPI
    private let mnemonic: String
    private let itemIdentifiers: [NSFileProviderItemIdentifier]
    private let completionHandler: (Error?) -> Void

    init(
        driveAPI: DriveAPI,
        mnemonic: String,
        itemIdentifiers: [NSFileProviderItemIdentifier],
        completionHandler: @escaping (Error?) -> Void
    ) {
        self.driveAPI          = driveAPI
        self.mnemonic          = mnemonic
        self.itemIdentifiers   = itemIdentifiers
        self.completionHandler = completionHandler
    }



    func run() -> Progress {
        Task {
            do {
               
                if let identifier = itemIdentifiers.first {
                    try await processItem(identifier: identifier)
                }
                completionHandler(nil)
            } catch {
                logger.error("❌ CopyInternxtLinkUseCase failed: \(error.localizedDescription)")
                completionHandler(error)
            }
        }
        return Progress()
    }



    private func processItem(identifier: NSFileProviderItemIdentifier) async throws {
        let internxtUUID: String
        let itemType: String
        
        if UUID(uuidString: identifier.rawValue) != nil {
            internxtUUID = identifier.rawValue
            itemType = "file"
        } else {
           
            let meta = try await driveAPI.getFolderOrFileMetaById(id: identifier.rawValue)
            guard let uuid = meta.uuid else {
                throw CopyInternxtLinkError.missingUUID(identifier.rawValue)
            }
            internxtUUID = uuid
            itemType = meta.isFolder ? "folder" : "file"
        }

        let cipher = InternxtAESCipher()
        let selectedDomain = try await fetchRandomDomain()
        let plainCode = cipher.generateRandomUrlSafeString(length: 8)
        let encryptionKey = try cipher.encrypt(plaintext: mnemonic, password: plainCode)

       
        let encryptedCode = try cipher.encrypt(plaintext: plainCode, password: mnemonic)
        let payload = CreateSharingPayload(
            itemId: internxtUUID,
            itemType: itemType,
            encryptionKey: encryptionKey,
            encryptionAlgorithm: "inxt-v2",
            encryptedCode: encryptedCode,
            encryptedPassword: nil,
            persistPreviousSharing: true
        )

        let response = try await driveAPI.createSharing(payload: payload)

        let recoveredCode = try cipher.decrypt(
            cipherBase64: response.encryptedCode,
            password: mnemonic
        )

        let encodedSharingId = encodeV4Uuid(response.id)
        let shareLink = "\(selectedDomain)/sh/\(itemType)/\(encodedSharingId)/\(recoveredCode)"
        await copyToClipboard(shareLink)
    }

    private func encodeV4Uuid(_ uuid: String) -> String {
        let hex = uuid.replacingOccurrences(of: "-", with: "")
        guard hex.count == 32 else { return uuid }

        var bytes = [UInt8]()
        bytes.reserveCapacity(16)
        var idx = hex.startIndex
        for _ in 0..<16 {
            let end = hex.index(idx, offsetBy: 2)
            if let byte = UInt8(hex[idx..<end], radix: 16) {
                bytes.append(byte)
            }
            idx = end
        }

        return Data(bytes).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }


    private func fetchRandomDomain() async throws -> String {
        do {
            let response = try await driveAPI.getShareDomains()
            guard !response.list.isEmpty else {
                logger.error("⚠️ Share domains list is empty")
                throw CopyInternxtLinkError.noDomainsAvailable
            }
            return response.list[Int.random(in: 0..<response.list.count)]
        } catch {
            logger.error("⚠️ Failed to fetch share domains: \(error.localizedDescription)")
            throw CopyInternxtLinkError.noDomainsAvailable
        }
    }


    @MainActor
    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        
        let alert = NSAlert()
        alert.messageText = "Link copied"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}



enum CopyInternxtLinkError: Error, LocalizedError {
    case missingUUID(String)
    case noDomainsAvailable

    var errorDescription: String? {
        switch self {
        case .missingUUID(let id):
            return "Could not resolve Internxt UUID for FileProvider identifier: \(id)"
        case .noDomainsAvailable:
            return "No share domains available from the gateway API"
        }
    }
}
