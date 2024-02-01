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
    var plain_name: String?
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
    var hasBackup: Bool = false

    var isCurrentDevice: Bool {
        return ConfigLoader().getDeviceName() == self.plain_name
    }

    init(id: Int, uuid: String, parentId: String?, parentUuid: String?, name: String?, plain_name: String? = nil, bucket: String?, user_id: Int?, encrypt_version: String?, deleted: Bool, deletedAt: String?, removed: Bool, removedAt: String?, createdAt: String, updatedAt: String, userId: Int?, parent_id: String?, hasBackup: Bool) {
        let decrypt = Decrypt()
        let config = ConfigLoader().get()

        self.id = id
        self.uuid = uuid
        self.parentId = parentId
        self.parentUuid = parentUuid
        self.name = name
        if let plainName = plain_name {
            self.plain_name = plainName
        } else {
            do {
                self.plain_name = try decrypt.decrypt(base64String: name ?? "", password: "\(config.CRYPTO_SECRET2)-\(bucket ?? "")")
            } catch {
                error.reportToSentry()
                self.plain_name = ""
            }
        }
        self.bucket = bucket
        self.user_id = user_id
        self.encrypt_version = encrypt_version
        self.deleted = deleted
        self.deletedAt = deletedAt
        self.removed = removed
        self.removedAt = removedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
        self.parent_id = parent_id
        self.hasBackup = hasBackup
    }

    init(from deviceAsFolder: DeviceAsFolder) {
        let decrypt = Decrypt()
        let config = ConfigLoader().get()

        self.id = deviceAsFolder.id
        self.uuid = deviceAsFolder.uuid
        self.parentId = deviceAsFolder.parentId
        self.parentUuid = deviceAsFolder.parentUuid
        self.name = deviceAsFolder.name
        if let plainName = deviceAsFolder.plain_name {
            self.plain_name = plainName
        } else {
            do {
                self.plain_name = try decrypt.decrypt(base64String: deviceAsFolder.name ?? "", password: "\(config.CRYPTO_SECRET2)-\(deviceAsFolder.bucket ?? "")")
            } catch {
                error.reportToSentry()
                self.plain_name = ""
            }
        }
        self.bucket = deviceAsFolder.bucket
        self.user_id = deviceAsFolder.user_id
        self.encrypt_version = deviceAsFolder.encrypt_version
        self.deleted = deviceAsFolder.deleted
        self.deletedAt = deviceAsFolder.deletedAt
        self.removed = deviceAsFolder.removed
        self.removedAt = deviceAsFolder.removedAt
        self.createdAt = deviceAsFolder.createdAt
        self.updatedAt = deviceAsFolder.updatedAt
        self.userId = deviceAsFolder.userId
        self.parent_id = deviceAsFolder.parent_id
        self.hasBackup = deviceAsFolder.hasBackup
    }

}
