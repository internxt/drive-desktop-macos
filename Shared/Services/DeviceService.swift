//
//  DeviceService.swift
//  SyncExtension
//
//  Created by Richard Ascanio on 1/18/24.
//

import Foundation
import InternxtSwiftCore

struct DeviceService {
    static var shared = DeviceService()
    private let backupAPI: BackupAPI = APIFactory.Backup
    private let decrypt = Decrypt()
    private let config = ConfigLoader().get()

    public func getAllDevices(deviceName: String?) async throws -> Array<Device> {
        let devicesAsFolder = try await backupAPI.getAllDevices()
        var filteredDevices: [Device] = []
        var currentDevice: Device? = nil

        let devices = devicesAsFolder.map { deviceAsFolder in
            return Device(id: deviceAsFolder.id, uuid: deviceAsFolder.uuid, parentId: deviceAsFolder.parentId, parentUuid: deviceAsFolder.parentUuid, name: deviceAsFolder.name, plain_name: deviceAsFolder.plain_name, bucket: deviceAsFolder.bucket, user_id: deviceAsFolder.user_id, encrypt_version: deviceAsFolder.encrypt_version, deleted: deviceAsFolder.deleted, deletedAt: deviceAsFolder.deletedAt, removed: deviceAsFolder.removed, removedAt: deviceAsFolder.removedAt, createdAt: deviceAsFolder.createdAt, updatedAt: deviceAsFolder.updatedAt, userId: deviceAsFolder.userId, parent_id: deviceAsFolder.parentId)
        }

        currentDevice = devices.first(where: { device in
            device.isCurrentDevice
        })

        if let currentDevice = currentDevice {
            filteredDevices.append(currentDevice)
        }

        filteredDevices.append(contentsOf: devices.filter { $0.name != currentDevice?.name })

        return filteredDevices
    }

    public func addCurrentDevice(deviceName: String) async throws {
        let _ = try await backupAPI.addDeviceAsFolder(deviceName: deviceName)
    }
}
