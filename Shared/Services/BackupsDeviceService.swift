//
//  DeviceService.swift
//  SyncExtension
//
//  Created by Richard Ascanio on 1/18/24.
//

import Foundation
import InternxtSwiftCore

struct BackupsDeviceService {
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "BackupsDevicesService")
    static var shared = BackupsDeviceService()
   
    private let decrypt = Decrypt()
    private let config = ConfigLoader().get()
    var currentDeviceId: Int? = nil

    public mutating func getAllDevices(deviceName: String?) async throws -> Array<Device> {
        let backupAPI = APIFactory.getBackupsClient()
        let devicesAsFolder = try await backupAPI.getAllDevices()
        var filteredDevices: [Device] = []
        var currentDevice: Device? = nil

        let devices = devicesAsFolder.map { deviceAsFolder in
            return Device(from: deviceAsFolder)
        }
        
        logger.info(["Devices as folder found:", devices.count])

        currentDevice = devices.first(where: { device in
            device.isCurrentDevice
        })

        if let currentDevice = currentDevice {
            self.currentDeviceId = currentDevice.id
            filteredDevices.append(currentDevice)
        }

        
        let devicesToReturn = devices.filter { device in
            return !(device.removed == true || device.deleted == true)
        }
        
       

        return devicesToReturn.sorted { (device1, device2) -> Bool in
            return device1.isCurrentDevice && !device2.isCurrentDevice
        }
    }

    public func getCurrentDevice() async throws -> Device? {
        let backupAPI = APIFactory.getBackupsClient()
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
        let backupAPI = APIFactory.getBackupsClient()
        _ = try await backupAPI.addDeviceAsFolder(deviceName: deviceName)
    }

    public func editDevice(deviceId: Int, deviceName: String) async throws -> Device {
        let backupAPI = APIFactory.getBackupsClient()
        let deviceAsFolder = try await backupAPI.editDeviceName(deviceId: deviceId, deviceName: deviceName)
        return Device(from: deviceAsFolder)
    }

    public func getDeviceFolders(deviceId: Int) async throws -> [GetFolderFoldersResult] {
        let deviceAPI = APIFactory.DriveNew
        let response = try await deviceAPI.getFolderFolders(folderId: "\(deviceId)")
        logger.info(["Get Backup Devices response: ", response])
        return response.result
    }
    
    public func getDeviceForPreview() -> Device {
        return Device(
            id: 1,
            uuid: UUID().uuidString,
            parentId: "parentId",
            parentUuid: UUID().uuidString,
            name: "encrypted_name",
            plainName: "Macbook Pro",
            bucket: nil,
            encryptVersion: nil,
            deleted: false,
            deletedAt: nil,
            removed: false,
            removedAt: nil,
            createdAt: "",
            updatedAt: "",
            userId: 123,
            hasBackups: true
        )
    }
}
