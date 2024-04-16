//
//  BackupsService.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/8/24.
//

import Foundation
import RealmSwift
import InternxtSwiftCore
import Combine

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
    case cannotGetDeviceId
    case folderToBackupRealmObjectNotFound
    case deviceCreatedButNotFound
    case deviceHasNoName
}

enum BackupDevicesFetchingStatus {
    case LoadingDevices
    case Ready
    case Failed
}
class BackupsService: ObservableObject {
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "App")
    var currentDevice: Device? = nil
    @Published var deviceResponse: Result<[Device], Error>? = nil
    @Published var foldersToBackup: [FolderToBackup] = []
    @Published var currentDeviceHasBackup = false
    private var service: XPCBackupServiceProtocol? = nil
    @Published var selectedDevice: Device? = nil
    @Published var currentBackupProgress: Double = 0.0
    @Published var backupStatus: BackupStatus = .Idle
    @Published var devicesFetchingStatus: BackupDevicesFetchingStatus = .LoadingDevices
    
    private var backupProgressTimer: AnyCancellable?
    private func getRealm() -> Realm {
        do {
            return try Realm(configuration: Realm.Configuration(
                fileURL: ConfigLoader.realmURL,
                deleteRealmIfMigrationNeeded: true
            ))
        } catch {
            error.reportToSentry()
            fatalError("Unable to open Realm")
        }

    }

    func clean() throws {
        DispatchQueue.main.async {
            self.foldersToBackup = []
            self.backupStatus = .Idle
            self.currentDeviceHasBackup = false
            self.selectedDevice = nil
            self.service = nil
            self.deviceResponse = nil
            self.devicesFetchingStatus = .LoadingDevices
        }
        
        try self.stopBackup()
        let realm = getRealm()
        try realm.write {
            realm.deleteAll()
        }
    }

    @MainActor func addFolderToBackup(url: URL) throws {

        do {
            let realm = getRealm()
            
            let folderToBackupRealmObject = FolderToBackupRealmObject(url: url.absoluteString, status: .selected)
            try realm.write {
                realm.add(folderToBackupRealmObject)
            }
            
            self.foldersToBackup.append(FolderToBackup(folderToBackupRealmObject: folderToBackupRealmObject))
        } catch {
            error.reportToSentry()
            throw BackupError.cannotAddFolder
        }
    }

    func removeFolderToBackup(id: String) async throws {
       
        do {
            let realm = getRealm()

            guard let folderToBackupRealmObject = realm.object(ofType: FolderToBackupRealmObject.self, forPrimaryKey: try ObjectId(string:id)) else {
                throw BackupError.folderToBackupRealmObjectNotFound
            }
            
            try realm.write {
                realm.delete(folderToBackupRealmObject)
            }

            
            self.assignUrls()
            
            //try await self.cleanBackupLocalData(folderUrl: folderToBackupRealmObject.url, realm: realm)
            //try await backupAPI.deleteBackupFolder(folderId: folderToBackupRealmObject.id, debug: true)
            
            await self.loadAllDevices()
        } catch {
            error.reportToSentry()
            throw BackupError.cannotDeleteFolder
        }
    }

    @MainActor func getFoldernames() -> [String] {
        let foldernamesToBackup = getRealm().objects(FolderToBackupRealmObject.self).sorted(byKeyPath: "createdAt", ascending: false)

        var array: [String] = []
        for foldername in foldernamesToBackup {
            if let url = URL(string: foldername.url) {
                array.append(url.lastPathComponent)
            }
        }

        return array
    }

    func assignUrls() {
        let folderToBackupRealmObjects = getRealm().objects(FolderToBackupRealmObject.self).sorted(byKeyPath: "createdAt", ascending: true)

        var foldersToBackup: [FolderToBackup] = []
        for folderToBackupRealmObject in folderToBackupRealmObjects {
            foldersToBackup.append(FolderToBackup(folderToBackupRealmObject: folderToBackupRealmObject))
        }
        logger.info("Got foldernames successfully")
        DispatchQueue.main.sync {
            self.foldersToBackup = foldersToBackup
        }
        
    }

    func loadAllDevices() async {
        
        do {
            
            DispatchQueue.main.sync{
                self.devicesFetchingStatus = .LoadingDevices
            }
            
            let currentDeviceName = ConfigLoader().getDeviceName()
            let allDevices = try await BackupsDeviceService.shared.getAllDevices(deviceName: currentDeviceName)
            let response: Result<[Device], Error> = .success(allDevices)
            
            
            logger.info("Got \(allDevices.count) devices successfully")
            
            if(allDevices.isEmpty) {
                throw BackupError.deviceCreatedButNotFound
            }
            
            DispatchQueue.main.async {
                self.deviceResponse = response
                self.selectedDevice = allDevices.first{device in
                    return device.plainName == currentDeviceName && device.removed != true && device.deleted != true
                }
                self.currentDevice = self.selectedDevice
                self.devicesFetchingStatus = .Ready
            }
        } catch {
            logger.error("Error fetching devices \(error)")
            
            DispatchQueue.main.async{
                self.devicesFetchingStatus = .Failed
                self.deviceResponse = .failure(error)
            }
            
            error.reportToSentry()
        }
    }

    func addCurrentDevice() async -> Void {
        do {
            if let currentDeviceName = ConfigLoader().getDeviceName() {
                try await BackupsDeviceService.shared.addCurrentDevice(deviceName: currentDeviceName)
                logger.info("Added current device \(currentDeviceName)")
            }
        } catch {
            error.reportToSentry()
            guard let apiError = error as? APIClientError else {
                return logger.error("Error adding device \(error)")
            }
            
            if(apiError.statusCode == 409) {
                logger.info("Device already registered, received a 409 status code from backend while registering the device")
            }
            
            
        }
    }

    private func getCurrentDevice() async throws -> Device {
        guard let currentDevice = try await BackupsDeviceService.shared.getCurrentDevice() else {
            throw BackupError.cannotGetCurrentDevice
        }

        return currentDevice
    }

    func updateDeviceDate(device: Device) async throws {
        
        guard let deviceName = ConfigLoader.shared.getDeviceName() else {
            throw BackupError.deviceHasNoName
        }
        logger.info("Updating device date with name: \(deviceName)")
        let _ = try await BackupsDeviceService.shared.editDevice(deviceId: device.id, deviceName: deviceName )
        await self.loadAllDevices()
    }

    func deleteBackup(deviceId: Int?) async throws -> Bool {
        guard let deviceId = deviceId else {
            throw BackupError.cannotGetDeviceId
        }

        var foldersIds: [Int] = []

        let getFoldersResponse = try await APIFactory.getNewBackupsClient().getBackupChilds(folderId: "\(deviceId)")

        foldersIds = getFoldersResponse.result.map { result in
            return result.id
        }

        for folderId in foldersIds {
            let _ = try await APIFactory.getBackupsClient().deleteBackupFolder(folderId: folderId)
        }

        let realm = getRealm()
        try realm.write {
            let allSyncedNodes = realm.objects(SyncedNode.self)
            realm.delete(allSyncedNodes)
        }

        return true
    }

    @MainActor private func cleanBackupLocalData(folderUrl: String, realm: Realm) async throws -> Void {
        // TODO: Make sure we clean all the RealmDB local data
        /* guard let syncedNode = realm.objects(SyncedNode.self).first(where: { node in
            node.url == folderUrl
        }) else {
            
            return true
        }

        return false */
    }

    func getDeviceFolders(deviceId: Int) async throws -> [GetFolderFoldersResult] {
        let folders = try await BackupsDeviceService.shared.getDeviceFolders(deviceId: deviceId)
        if BackupsDeviceService.shared.currentDeviceId == deviceId {
            self.currentDeviceHasBackup = !folders.isEmpty
        }
        return folders
    }

    private func formatFolderURL(url: String) -> String {
        return url.replacingOccurrences(of: "file://", with: "")
    }

    private func propagateError(errorMessage: String) {
        logger.info("Error backing up device")
        DispatchQueue.main.async { [weak self] in
            self?.currentDeviceHasBackup = true
            self?.backupStatus = .Failed
        }
    }

    private func propagateSuccess() {
        logger.info("Device backed up successfully")
        DispatchQueue.main.async { [weak self] in
            self?.currentBackupProgress = 1
            self?.currentDeviceHasBackup = true
        }
        Task {
            do {
                guard let currentDevice = self.currentDevice else {
                    throw BackupError.cannotGetCurrentDevice
                }
                try await self.updateDeviceDate(device: currentDevice)
                DispatchQueue.main.async {
                    self.backupStatus = .Done
                }
                
                await UsageManager.shared.updateUsage()
                
            } catch {
                logger.error("Cannot update device date \(error)")
                error.reportToSentry()
            }
        }
    }

    func startBackup(onProgress: @escaping (Double) -> Void) async throws {
        logger.info("Backup started")
        logger.info("Going to backup folders \(self.foldersToBackup)")
        
        if self.foldersToBackup.isEmpty {
            logger.error("Foldernames are empty")
            throw BackupError.emptyFolders
        }

        DispatchQueue.main.sync {
            self.backupStatus = .InProgress
            self.currentBackupProgress = 0
        }
        
        let currentDevice = try await self.getCurrentDevice()
        logger.info("Current device id \(currentDevice.id)")

        guard let bucketId = currentDevice.bucket else {
            logger.error("Bucket id is nil")
            throw BackupError.bucketIdIsNil
        }

        let authManager = AuthManager()
        guard let mnemonic = authManager.mnemonic else {
            logger.error("Cannot get mnemonic")
            throw BackupError.cannotGetMnemonic
        }

        logger.info("Setting connection to XPCBackupService...")
        //Connection to xpc service
        let connectionToService = NSXPCConnection(serviceName: "com.internxt.XPCBackupService")
        connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
        connectionToService.resume()

        var initializationError: Error? = nil

        service = connectionToService.remoteObjectProxyWithErrorHandler { error in
            initializationError = error
        } as? XPCBackupServiceProtocol
        
        if let error = initializationError {
            logger.error("XPC Service initialization error")
            throw error
        }

        guard let service = service else {
            logger.error("XPC Service is nil")
            throw BackupError.cannotInitializeXPCService
        }
        
        logger.info("✅ Connection to XPCBackupService stablished")
        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
        let authToken = configLoader.getLegacyAuthToken()
        let newAuthToken = configLoader.getAuthToken()

        guard let authToken = authToken, let newAuthToken = newAuthToken else {
            logger.error("Cannot create auth token")
            throw BackupError.cannotCreateAuthToken
        }

        let urlsStrings = foldersToBackup.map { folderToBackup in folderToBackup.url.absoluteString.replacingOccurrences(of: "file://", with: "").removingPercentEncoding ?? "" }


        service.startBackup(backupAt: urlsStrings, mnemonic: mnemonic, networkAuth: networkAuth, authToken: authToken, newAuthToken: newAuthToken, deviceId: currentDevice.id, bucketId: bucketId, with: { response, error in
            if let error = error {
                self.propagateError(errorMessage: error)
            } else {
                self.propagateSuccess()
            }
        })
        
        
        backupProgressTimer?.cancel()
        self.backupProgressTimer = Timer.publish(every: 2, on:.main, in: .common)
            .autoconnect()
            .sink(
             receiveValue: {_ in
                 self.checkBackupProgress()
            })
    }

    func stopBackup() throws {
        logger.debug("Going to stop backup")
        DispatchQueue.main.async {
            self.backupStatus = .Idle
        }
        
        service?.stopBackup()
    }
             
    func checkBackupProgress() {
        self.logger.info("Getting progress")
        service?.getBackupStatus{backupStatusUpdate, error in
            guard let backupStatus = backupStatusUpdate else {
                return
            }
            
            if(backupStatus.totalSyncs == 0) {
                return
            }
            
            DispatchQueue.main.async {
                
                self.backupStatus = backupStatusUpdate?.status ?? .Idle
                self.currentBackupProgress = backupStatusUpdate?.progress ?? 0
                self.logger.info(["Backup is in \(backupStatus.status) status, \(backupStatus.completedSyncs) of \(backupStatus.totalSyncs) nodes synced, \(self.currentBackupProgress * 100)% synced"])
            }
            
            if(backupStatusUpdate?.status == .Done || backupStatusUpdate?.status == .Failed) {
                self.backupProgressTimer?.cancel()
            }
        }
    }

}

class FolderToBackup {
    let id: String
    let url: URL
    let status: FolderToBackupStatus
    let createdAt: Date
    
    init(folderToBackupRealmObject: FolderToBackupRealmObject) {
        self.id = folderToBackupRealmObject.id
        self.url = URL(fileURLWithPath: folderToBackupRealmObject.url.removingPercentEncoding?.replacingOccurrences(of: "file://", with: "") ?? "")
        self.status = folderToBackupRealmObject.status
        self.createdAt = folderToBackupRealmObject.createdAt
    }
    
    init(id: String,url: URL, status: FolderToBackupStatus, createdAt: Date) {
        self.id = id
        self.url = url
        self.status = status
        self.createdAt = createdAt
    }
}


class FolderToBackupRealmObject: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var url: String
    @Persisted var status: FolderToBackupStatus
    @Persisted var createdAt: Date

    convenience init(
        url: String,
        status: FolderToBackupStatus
    ) {
        self.init()
        self.url = url
        self.createdAt = Date()
        self.status = status
    }
}

extension FolderToBackupRealmObject: Identifiable {
    var id: String {
        return _id.stringValue
    }
}

enum FolderToBackupStatus: String, PersistableEnum {
    case hasIssues
    case selected
    case inProgress
}
