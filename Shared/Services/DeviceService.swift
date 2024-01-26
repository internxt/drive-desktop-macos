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

    public func getAllDevices() async throws -> Array<Device> {
        let devices = try await backupAPI.getAllDevices()
        return devices
    }
}
