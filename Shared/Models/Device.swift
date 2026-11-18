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
    let status: String
    let createdAt: String
    let updatedAt: String
    let userId: Int?
    var hasBackups: Bool = false

    var isCurrentDevice: Bool {
        return ConfigLoader().getDeviceName() == self.plainName && DriveItemStatus(rawValue: self.status) == .exists
    }

    init(id: Int, uuid: String, parentId: String?, parentUuid: String?, name: String?, plainName: String? = nil, bucket: String?, encryptVersion: String?, status: String = "EXISTS", createdAt: String, updatedAt: String, userId: Int?, hasBackups: Bool) {
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
        self.status = status
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
        if let plainName = deviceAsFolder.plainName {
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
        self.status = deviceAsFolder.status
        self.createdAt = deviceAsFolder.createdAt
        self.updatedAt = deviceAsFolder.updatedAt
        self.userId = deviceAsFolder.user_id ?? deviceAsFolder.userId
        self.hasBackups = deviceAsFolder.hasBackups ?? false
    }

}
