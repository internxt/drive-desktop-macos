//
//  BackupsService.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/8/24.
//

import Foundation
import RealmSwift
import InternxtSwiftCore
import os.log

enum BackupError: Error {
    case cannotCreateURL
    case cannotAddFolder
    case cannotDeleteFolder
    case cannotFindFolder
    case emptyFolders
    case cannotGetMnemonic
    case cannotGetCurrentDevice
    case bucketIdIsNil
    case cannotInitializeXPCService
    case cannotCreateAuthToken
}

class BackupsService: ObservableObject {
    private let logger = Logger(subsystem: "com.internxt", category: "BackupsService")
    @Published var deviceResponse: Result<[Device], Error>? = nil
    @Published var foldernames: [FoldernameToBackup] = []
    private let connectionToService = NSXPCConnection(serviceName: "com.internxt.XPCBackupService")

    private func getRealm() -> Realm {
        do {
            return try Realm(fileURL: ConfigLoader.realmURL)
        } catch {
            error.reportToSentry()
            fatalError("Unable to open Realm")
        }

    }

    func clean() throws {
        foldernames = []
        let realm = getRealm()
        try realm.write {
            realm.deleteAll()
        }
    }

    func addFoldernameToBackup(_ foldernameToBackup: FoldernameToBackup) throws {
        guard let _ = URL(string: foldernameToBackup.url) else {
            throw BackupError.cannotCreateURL
        }

        do {
            let realm = getRealm()
            try realm.write {
                realm.add(foldernameToBackup)
            }
            self.foldernames.append(foldernameToBackup)
        } catch {
            error.reportToSentry()
            throw BackupError.cannotAddFolder
        }
    }

    func removeFoldernameFromBackup(id: String) throws {
        let itemToDelete = foldernames.first { foldername in
            return foldername.id == id
        }
        guard let itemToDelete = itemToDelete else {
            throw BackupError.cannotFindFolder
        }

        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(itemToDelete)
            }
            self.assignUrls()
        } catch {
            error.reportToSentry()
            throw BackupError.cannotDeleteFolder
        }
    }

    func getFoldernames() -> [String] {
        let foldernamesToBackup = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: false)

        var array: [String] = []
        for foldername in foldernamesToBackup {
            if let url = URL(string: foldername.url) {
                array.append(url.lastPathComponent)
            }
        }

        return array
    }

    func assignUrls() {
        let foldernamesToBackup = getRealm().objects(FoldernameToBackup.self).sorted(byKeyPath: "createdAt", ascending: true)

        var folders: [FoldernameToBackup] = []
        for foldername in foldernamesToBackup {
            if let _ = URL(string: foldername.url) {
                folders.append(foldername)
            }
        }
        self.foldernames = folders
    }

    func loadAllDevices() async {
        do {
            self.deviceResponse = .success(try await DeviceService.shared.getAllDevices(deviceName: ConfigLoader().getDeviceName()))
        } catch {
            error.reportToSentry()
            self.deviceResponse = .failure(error)
        }
    }

    func addCurrentDevice() async {
        do {
            if let currentDeviceName = ConfigLoader().getDeviceName() {
                try await DeviceService.shared.addCurrentDevice(deviceName: currentDeviceName)
            }
        } catch {
            error.reportToSentry()
        }
    }

    private func getCurrentDevice() async throws -> Device {
        guard let currentDevice = try await DeviceService.shared.getCurrentDevice() else {
            throw BackupError.cannotGetCurrentDevice
        }

        return currentDevice
    }

    private func formatFolderURL(url: String) -> String {
        return url.replacingOccurrences(of: "file://", with: "")
    }

    private func propagateError(errorMessage: String, url: URL) throws {
        throw AppError.notImplementedError
    }

    private func propagateSuccess(url: URL) {
        logger.info("Backed up \(url) succesfully")
        //TODO: propagate success backup to UI component
    }

    @MainActor func startBackup(for folders: [FoldernameToBackup]) async throws {
        if self.foldernames.isEmpty {
            throw BackupError.emptyFolders
        }

        let currentDevice = try await self.getCurrentDevice()

        guard let bucketId = currentDevice.bucket else {
            throw BackupError.bucketIdIsNil
        }

        let authManager = AuthManager()
        guard let mnemonic = authManager.mnemonic else {
            throw BackupError.cannotGetMnemonic
        }

        //Connection to xpc service
        connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
        connectionToService.resume()

        var initializationError: Error? = nil

        let service = connectionToService.remoteObjectProxyWithErrorHandler { error in
            initializationError = error
        } as? XPCBackupServiceProtocol

        if let error = initializationError {
            throw error
        }

        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
        let authToken = configLoader.getLegacyAuthToken()

        guard let authToken = authToken else {
            throw BackupError.cannotCreateAuthToken
        }

        let urls = folders.map { URL(fileURLWithPath: self.formatFolderURL(url: $0.url)) }

        for url in urls {
            logger.info("Going to backup url \(url)")
            service?.startBackup(backupAt: url, mnemonic: mnemonic, networkAuth: networkAuth, authToken: authToken, deviceId: currentDevice.id, bucketId: bucketId, with: { _, error in
                if let error = error {
                    try? self.propagateError(errorMessage: error, url: url)
                } else {
                    self.propagateSuccess(url: url)
                }
            })
        }

    }
}

class FoldernameToBackup: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var url: String
    @Persisted var status: FoldernameToBackupStatus
    @Persisted var createdAt: Date

    convenience init(
        url: String,
        status: FoldernameToBackupStatus
    ) {
        self.init()
        self.url = url
        self.createdAt = Date()
        self.status = status
    }
}

extension FoldernameToBackup: Identifiable {
    var id: String {
        return _id.stringValue
    }
}

enum FoldernameToBackupStatus: String, PersistableEnum {
    case hasIssues
    case selected
    case inProgress
}
