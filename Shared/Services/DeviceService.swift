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
        let devices = try await backupAPI.getAllDevices()
        var filteredDevices: [Device] = []
        var currentDevice: Device? = nil

        for device in devices {
            let plainDeviceName = try decrypt.decrypt(base64String: device.name ?? "", password: "\(config.CRYPTO_SECRET2)-\(device.bucket ?? "")")

            if plainDeviceName == deviceName {
                currentDevice = device
            }
        }

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
