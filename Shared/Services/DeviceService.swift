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
            return Device(from: deviceAsFolder)
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

    public func getCurrentDevice() async throws -> Device? {
        let devicesAsFolder = try await backupAPI.getAllDevices()

        let devices = devicesAsFolder.map { deviceAsFolder in
            return Device(from: deviceAsFolder)
        }

        let currentDevice = devices.first(where: { device in
            device.isCurrentDevice
        })

        return currentDevice
    }

    public func addCurrentDevice(deviceName: String) async throws {
        let _ = try await backupAPI.addDeviceAsFolder(deviceName: deviceName)
    }
}
