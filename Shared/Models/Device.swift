//
//  Device.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/30/24.
//

import Foundation
import InternxtSwiftCore

struct Device: Codable, Identifiable {
    let id: Int
    let uuid: String
    let parentId: String?
    let parentUuid: String?
    let name: String?
    let plain_name: String?
    let bucket: String?
    let user_id: Int?
    let encrypt_version: String?
    let deleted: Bool
    let deletedAt: String?
    let removed: Bool
    let removedAt: String?
    let createdAt: String
    let updatedAt: String
    let userId: Int?
    let parent_id: String?

    var decryptedName: String {
        let decrypt = Decrypt()
        let config = ConfigLoader().get()

        do {
            return try decrypt.decrypt(base64String: self.name ?? "", password: "\(config.CRYPTO_SECRET2)-\(self.bucket ?? "")")
        } catch {
            error.reportToSentry()
            return ""
        }
    }

    var isCurrentDevice: Bool {
        return ConfigLoader().getDeviceName() == self.decryptedName
    }
}
