//
//  DeviceService.swift
//  SyncExtension
//
//  Created by Richard Ascanio on 1/18/24.
//

import Foundation
import InternxtSwiftCore

struct DeviceService {
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "App")
    static var shared = DeviceService()
    private let backupAPI: BackupAPI = APIFactory.Backup
    private let deviceAPI: DriveAPI = APIFactory.DriveNew
    private let decrypt = Decrypt()
    private let config = ConfigLoader().get()
    var currentDeviceId: Int? = nil

    public mutating func getAllDevices(deviceName: String?) async throws -> Array<Device> {
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
            self.currentDeviceId = currentDevice.id
            filteredDevices.append(currentDevice)
        }

        filteredDevices.append(contentsOf: devices.filter { $0.name != currentDevice?.name })

        let devicesToReturn = filteredDevices.filter { !$0.deleted }

        return devicesToReturn
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

    public func editDevice(deviceId: Int, deviceName: String) async throws -> Device {
        let deviceAsFolder = try await backupAPI.editDeviceName(deviceId: deviceId, deviceName: deviceName)
        return Device(from: deviceAsFolder)
    }

    public func getDeviceFolders(deviceId: Int) async throws -> [GetFolderFoldersResult] {
        let response = try await deviceAPI.getFolderFolders(folderId: "\(deviceId)")
        return response.result
    }
}
