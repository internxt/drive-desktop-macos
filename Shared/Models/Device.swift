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
    var plainName: String?
    let bucket: String?
    let encryptVersion: String?
    let deleted: Bool
    let deletedAt: String?
    let removed: Bool
    let removedAt: String?
    let createdAt: String
    let updatedAt: String
    let userId: Int?
    var hasBackups: Bool = false

    var isCurrentDevice: Bool {
        return ConfigLoader().getDeviceName() == self.plainName && self.deleted != true && self.removed != true
    }

    init(id: Int, uuid: String, parentId: String?, parentUuid: String?, name: String?, plainName: String? = nil, bucket: String?, encryptVersion: String?, deleted: Bool, deletedAt: String?, removed: Bool, removedAt: String?, createdAt: String, updatedAt: String, userId: Int?, hasBackups: Bool) {
        let decrypt = Decrypt()

        self.id = id
        self.uuid = uuid
        self.parentId = parentId
        self.parentUuid = parentUuid
        self.name = name
        if let plainName = plainName {
            self.plainName = plainName
        } else {
            do {
                self.plainName = try decrypt.decrypt(base64String: name ?? "", password: "\(DecryptUtils().getDecryptPassword(bucketId: bucket ?? ""))")
            } catch {
                error.reportToSentry()
                self.plainName = ""
            }
        }
        self.bucket = bucket
        self.encryptVersion = encryptVersion
        self.deleted = deleted
        self.deletedAt = deletedAt
        self.removed = removed
        self.removedAt = removedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.userId = userId
        self.hasBackups = hasBackups
    }

    init(from deviceAsFolder: DeviceAsFolder) {
        let decrypt = Decrypt()

        self.id = deviceAsFolder.id
        self.uuid = deviceAsFolder.uuid
        self.parentId = deviceAsFolder.parentId
        self.parentUuid = deviceAsFolder.parentUuid
        self.name = deviceAsFolder.name
        if let plainName = deviceAsFolder.plain_name {
            self.plainName = plainName
        } else {
            do {
                self.plainName = try decrypt.decrypt(base64String: deviceAsFolder.name ?? "", password: "\(DecryptUtils().getDecryptPassword(bucketId: deviceAsFolder.bucket ?? ""))")
            } catch {
                error.reportToSentry()
                self.plainName = ""
            }
        }
        self.bucket = deviceAsFolder.bucket
        self.encryptVersion = deviceAsFolder.encrypt_version
        self.deleted = deviceAsFolder.deleted
        self.deletedAt = deviceAsFolder.deletedAt
        self.removed = deviceAsFolder.removed
        self.removedAt = deviceAsFolder.removedAt
        self.createdAt = deviceAsFolder.createdAt
        self.updatedAt = deviceAsFolder.updatedAt
        self.userId = deviceAsFolder.user_id ?? deviceAsFolder.userId
        self.hasBackups = deviceAsFolder.hasBackups ?? false
    }

}
