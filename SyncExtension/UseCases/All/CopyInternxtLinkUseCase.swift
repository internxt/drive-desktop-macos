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

  
 
    private static let shareBaseURL = "https://drive.internxt.com"


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
                for identifier in itemIdentifiers {
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
        let uuid = identifier.rawValue
        logger.info("Generating Internxt sharing link for item: \(uuid)")

        let cipher = InternxtAESCipher()

       
        let plainCode = cipher.generateRandomUrlSafeString(length: 8)


        let encryptionKey = try cipher.encrypt(plaintext: mnemonic, password: plainCode)

  
        let encryptedCode = try cipher.encrypt(plaintext: plainCode, password: mnemonic)


        let itemType = UUID(uuidString: uuid) != nil ? "file" : "folder"


        let payload = CreateSharingPayload(
            itemId: uuid,
            itemType: itemType,
            encryptionKey: encryptionKey,
            encryptionAlgorithm: "inxt-v2",
            encryptedCode: encryptedCode,
            encryptedPassword: "",
            persistPreviousSharing: true
        )


        _ = try await driveAPI.createSharing(payload: payload)

        logger.info("✅ Sharing created for item \(uuid)")


        logger.info("⚠️ Link generation pending: CreateSharingResponse fields not yet defined.")
    }



    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        logger.info("📋 Internxt share link copied to clipboard: \(text)")
    }
}
