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
import AppKit


struct ItemBackup: Identifiable{
    let id = UUID()
    let itemId: String
    let device: Device
}


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
    case invalidDownloadURL
    case missingNetworkAuth
    case storageFull
    case missingNetworkConnection
}

enum BackupDevicesFetchingStatus {
    case LoadingDevices
    case Ready
    case Failed
}

enum BackupState: Equatable {
    case locked
    case active
}
class BackupsService: ObservableObject {
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "App")
    var currentDevice: Device? = nil
    let activityManager = ActivityManager()
    @Published var thereAreMissingFoldersToBackup = false
    @Published var deviceResponse: Result<[Device], Error>? = nil
    @Published var foldersToBackup: [FolderToBackup] = []
    @Published var currentDeviceHasBackup = false
    private var xpcBackupService: XPCBackupServiceProtocol? = nil
    @Published var selectedDevice: Device? = nil
    @Published var backupUploadProgress: Double = 0.0
    @Published var backupDownloadedItems: Int64 = 0
    @Published var backupUploadStatus: BackupStatus = .Idle
    @Published var backupDownloadStatus: BackupStatus = .Idle
    @Published var deviceDownloading: Device? = nil
    @Published var devicesFetchingStatus: BackupDevicesFetchingStatus = .LoadingDevices
    @Published var backupsItemsInprogress: [ItemBackup] = []
    private var backupFoldersToBackup: [FolderToBackupRealmObject] = []
    private var backupUploadProgressTimer: AnyCancellable?
    private var backupDownloadProgressTimer: AnyCancellable?
    @Published var currentBackupState: BackupState = .active
    private let LAST_BACKUP_TIME_KEY = "INTERNXT_LAST_BACKUP_TIME_KEY"

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
            self.backupUploadStatus = .Idle
            self.backupDownloadStatus = .Idle
            self.currentDeviceHasBackup = false
            self.selectedDevice = nil
            self.xpcBackupService = nil
            self.deviceResponse = nil
            self.devicesFetchingStatus = .LoadingDevices
            self.backupsItemsInprogress = []
        }
        
        try self.stopBackupUpload()
        try self.stopBackupDownload()
        let realm = getRealm()
        try realm.write {
            realm.deleteAll()
        }
    }

    @MainActor func addFolderToBackup(url: URL) throws {

        do {
            let realm = getRealm()
            
            let folderToBackupRealmObject = FolderToBackupRealmObject(url: url, status: .selected)
            try realm.write {
                realm.add(folderToBackupRealmObject)
            }
            
            self.foldersToBackup.append(FolderToBackup(folderToBackupRealmObject: folderToBackupRealmObject))
        } catch {
            error.reportToSentry()
            throw BackupError.cannotAddFolder
        }
    }

    func removeFolderToBackup(folderToBackupId: String) async throws {
       
        do {
            let realm = getRealm()

            guard let folderToBackupRealmObject = realm.object(ofType: FolderToBackupRealmObject.self, forPrimaryKey: try ObjectId(string:folderToBackupId)) else {
                throw BackupError.folderToBackupRealmObjectNotFound
            }
            
            try realm.write {
                realm.delete(folderToBackupRealmObject)
            }

            
            self.loadFoldersToBackup()
            
            //try await self.cleanBackupLocalData(folderUrl: folderToBackupRealmObject.url, realm: realm)
            //try await backupAPI.deleteBackupFolder(folderId: folderToBackupRealmObject.id, debug: true)
            
            await self.loadAllDevices()
        } catch {
            error.reportToSentry()
            throw BackupError.cannotDeleteFolder
        }
    }
    
    func restoreFolderToBackup() async {
        do {
            let realm = getRealm()
            try realm.write {
                realm.delete(realm.objects(FolderToBackupRealmObject.self))
                
                backupFoldersToBackup.forEach { realm.add($0) }
                self.loadFoldersToBackup()
            }
        } catch {
            logger.error("Error to restore folders to backup")

        }
    }
    
    func initFolderToBackup() async {
        
        let realm = getRealm()
        backupFoldersToBackup = realm.objects(FolderToBackupRealmObject.self).map { $0.clone() }
        
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

    func loadFoldersToBackup() {
        let folderToBackupRealmObjects = getRealm().objects(FolderToBackupRealmObject.self).sorted(byKeyPath: "createdAt", ascending: true)
        var folderToBackupMissing = false
        var foldersToBackup: [FolderToBackup] = []
        for folderToBackupRealmObject in folderToBackupRealmObjects {
            let folderToBackup = FolderToBackup(folderToBackupRealmObject: folderToBackupRealmObject)
            if folderToBackupMissing == false {
                folderToBackupMissing = folderToBackup.folderIsMissing()
            }
                
            foldersToBackup.append(folderToBackup)
        }
        
        
        DispatchQueue.main.async {
            self.thereAreMissingFoldersToBackup = folderToBackupMissing
            self.foldersToBackup = foldersToBackup
            if self.thereAreMissingFoldersToBackup {
                self.logger.info(["Unable to locate some folders to backup"])
            }
            
            self.logger.info(["Got FoldersToBackup successfully", self.foldersToBackup])
        }
        
        
        
    }
    
    func updateFolderToBackupURL(folderId: String, newURL: URL) throws {
        let realm = getRealm()
        let folderToBackupRealmObject = realm.object(ofType: FolderToBackupRealmObject.self,
                                                     forPrimaryKey: try ObjectId(string: folderId))
        
        guard let folderToBackupRealmObjectUnwrapped = folderToBackupRealmObject else {
            return
        }
        try realm.write{
            folderToBackupRealmObjectUnwrapped.url = newURL.absoluteString
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
                let currentDevice = allDevices.first{device in
                    return device.plainName == currentDeviceName && device.removed != true && device.deleted != true
                }
                if self.selectedDevice == nil {
                    self.selectedDevice = currentDevice 
                }
                
                self.logger.info("Device updated at date is: \(self.selectedDevice?.updatedAt) ")
                self.currentDevice = currentDevice
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
        logger.info("Updating device \(device.id) date with name: \(deviceName) at \(Date())")
        let updatedCurrentDevice = try await BackupsDeviceService.shared.editDevice(deviceUuid: device.uuid, deviceName: deviceName )
        DispatchQueue.main.sync {
            self.currentDevice = updatedCurrentDevice
            self.selectedDevice = self.currentDevice
        }
        
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
            let foldersToBackup = realm.objects(FolderToBackupRealmObject.self)
            realm.delete(foldersToBackup)
        }
        
        DispatchQueue.main.async {
            self.foldersToBackup = []
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
            self?.backupUploadStatus = .Failed
            Analytics.shared.track(event: FailureBackupEvent(foldersToBackup: self?.foldersToBackup.count ?? 0, error: errorMessage))
        }
    }

    private func propagateUploadSuccess() {
        logger.info("Device backed up successfully, tracking backup success event")
        Analytics.shared.track(event: SuccessBackupEvent(foldersToBackup: self.foldersToBackup.count))
        DispatchQueue.main.async { [weak self] in
            self?.backupUploadProgress = 1
            self?.currentDeviceHasBackup = true
        }
        Task {
            do {
                

                guard let currentDevice = self.currentDevice else {
                    throw BackupError.cannotGetCurrentDevice
                }
                try await self.updateDeviceDate(device: currentDevice)
                DispatchQueue.main.async {
                    self.backupUploadStatus = .Done
                }
                
                await UsageManager.shared.updateUsage()
            } catch {
                if let apiError = error as? APIClientError {
                    logger.error("Cannot update device date \(String(decoding:apiError.responseBody, as:  UTF8.self))")
                } else {
                    logger.error("Cannot update device date \(error)")
                }
                
                error.reportToSentry()
            }
        }
    }

    func startBackup(onProgress: @escaping (Double) -> Void) async throws {
        guard NetworkConnectivityService.shared.isNetworkAvailable() else {
            logger.error("The Internet connection appears to be offline.")
            throw BackupError.missingNetworkConnection
        }
        
        logger.info("Backup started")
        logger.info("Going to backup folders \(self.foldersToBackup)")
        
        if self.foldersToBackup.isEmpty {
            logger.error("There are no folders selected for backup, cannot start one.")
            return
        }

        DispatchQueue.main.sync {
            self.backupUploadStatus = .InProgress
            self.backupUploadProgress = 0
        }
        
        let currentDevice = try await self.getCurrentDevice()
        logger.info("Current device id \(currentDevice.id)")

        guard let bucketId = currentDevice.bucket else {
            logger.error("Bucket id is nil")
            throw BackupError.bucketIdIsNil
        }

        logger.info("Setting connection to XPCBackupService...")
        //Connection to xpc service
        let xpcBackupService = try await getXPCBackupServiceProtocol(onConnectionIssue: {
            self.logger.error("❌ XPCBackupService connection interrupted")
        })
        
        logger.info("✅ Connection to XPCBackupService stablished")
        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
    

        let urlsStrings = foldersToBackup.map { folderToBackup in folderToBackup.url.absoluteString.replacingOccurrences(of: "file://", with: "").removingPercentEncoding ?? "" }


        xpcBackupService.uploadDeviceBackup(backupAt: urlsStrings,networkAuth: networkAuth,deviceId: currentDevice.id, deviceUuid: currentDevice.uuid, bucketId: bucketId, with: { response, error in
            if let error = error {
                if error == "storageFull"{
                    self.showAlert()
                }else {
                    self.propagateError(errorMessage: error)
                }
            } else {
                self.propagateUploadSuccess()
            }
        })
        
        
        backupUploadProgressTimer?.cancel()
        self.backupUploadProgressTimer = Timer.publish(every: 2, on:.main, in: .common)
            .autoconnect()
            .sink(
             receiveValue: {_ in
                 self.checkBackupUploadProgress()
            })
    }
    
    func downloadBackup(device: Device, downloadAt: URL) async throws {
        guard NetworkConnectivityService.shared.isNetworkAvailable() else {
            logger.error("The Internet connection appears to be offline.")
            throw BackupError.missingNetworkConnection
        }
        
        self.deviceDownloading = device
        logger.info("Preparint backup for download")
        logger.info("Device to download is \(device.plainName) with ID \(device.id)")
        
        DispatchQueue.main.sync {
            self.backupDownloadStatus = .InProgress
            self.backupDownloadedItems = 0
        }
        guard let deviceBucketId = device.bucket else {
            logger.error("Bucket id is nil")
            throw BackupError.bucketIdIsNil
        }


        logger.info("Setting connection to XPCBackupService...")
        
        let xpcBackupService = try await getXPCBackupServiceProtocol(onConnectionIssue: {
            self.logger.error("❌ XPCBackupService connection interrupted")
        })
        
        logger.info("✅ Connection to XPCBackupService stablished")
        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
        
        guard let URLAsString = downloadAt.absoluteString.replacingOccurrences(of: "file://", with: "").removingPercentEncoding else {
            throw BackupError.invalidDownloadURL
        }

        guard let networkAuthUnwrapped = networkAuth else {
            throw BackupError.missingNetworkAuth
        }
        
        backupDownloadProgressTimer?.cancel()
        xpcBackupService.downloadDeviceBackup(
            downloadAt: URLAsString,
            networkAuth: networkAuthUnwrapped,
            deviceId:device.id,
            bucketId: deviceBucketId,
            with: {result, error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.backupDownloadStatus = .Done
                    }
                    
                    self.completeBackupDownload()
                } else {
                    self.backupDownloadStatus = .Failed
                }
                self.logger.info(["Received backup download response", result, error])
            }
        )
        
        backupDownloadProgressTimer?.cancel()
        self.backupDownloadProgressTimer = Timer.publish(every: 2, on:.main, in: .common)
            .autoconnect()
            .sink(
             receiveValue: {_ in
                 self.checkBackupDownloadProgress(xpcBackupService: xpcBackupService)
            })

    }
    
    func downloadFolderBackup(device: Device, downloadAt: URL, folderId: String, folderName: String? = "") async throws {
        guard NetworkConnectivityService.shared.isNetworkAvailable() else {
            logger.error("The Internet connection appears to be offline.")
            throw BackupError.missingNetworkConnection
        }
        
        logger.info("Preparint  folder backup for download")
        let itemBackup = ItemBackup(itemId: folderId, device: device)
        DispatchQueue.main.sync {
            self.backupsItemsInprogress.append(itemBackup)
        }
        guard let deviceBucketId = device.bucket else {
            logger.error("Bucket id is nil")
            throw BackupError.bucketIdIsNil
        }


        logger.info("Setting connection to XPCBackupService...")
        
        let xpcBackupService = try await getXPCBackupServiceProtocol(onConnectionIssue: {
            self.logger.error("❌ XPCBackupService connection interrupted")
        })
        
        logger.info("✅ Connection to XPCBackupService stablished")
        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
        
        guard let URLAsString = downloadAt.absoluteString.replacingOccurrences(of: "file://", with: "").removingPercentEncoding else {
            throw BackupError.invalidDownloadURL
        }

        guard let networkAuthUnwrapped = networkAuth else {
            throw BackupError.missingNetworkAuth
        }
        
        backupDownloadProgressTimer?.cancel()
        xpcBackupService.downloadFolderBackup(
            downloadAt: URLAsString,
            networkAuth: networkAuthUnwrapped,
            folderId:folderId,
            bucketId: deviceBucketId, folderName: folderName ?? "",
            with: {result, error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.removeItem(item: itemBackup)
                    }
                    self.logger.info("Backup Folder downloaded✅")
                } else {
                    self.removeItem(item: itemBackup)
                }
                self.logger.info(["Received backup download response", result, error])
            }
        )
        
        backupDownloadProgressTimer?.cancel()
//        self.backupDownloadProgressTimer = Timer.publish(every: 2, on:.main, in: .common)
//            .autoconnect()
//            .sink(
//             receiveValue: {_ in
//                 self.checkBackupDownloadProgress(xpcBackupService: xpcBackupService)
//            })

    }
    
    func downloadFileBackup(device: Device, downloadAt: URL, fileId: String) async throws {
        guard NetworkConnectivityService.shared.isNetworkAvailable() else {
            logger.error("The Internet connection appears to be offline.")
            throw BackupError.missingNetworkConnection
        }
        
        logger.info("Preparint backup file for download")
        let itemBackup = ItemBackup(itemId: fileId, device: device)
        
        DispatchQueue.main.sync {
            self.backupsItemsInprogress.append(itemBackup)
        }
        guard let deviceBucketId = device.bucket else {
            logger.error("Bucket id is nil")
            throw BackupError.bucketIdIsNil
        }
        
        logger.info("Setting connection to XPCBackupService...")
        
        let xpcBackupService = try await getXPCBackupServiceProtocol(onConnectionIssue: {
            self.logger.error("❌ XPCBackupService connection interrupted")
        })
        
        logger.info("✅ Connection to XPCBackupService stablished")
        let configLoader = ConfigLoader()
        let networkAuth = configLoader.getNetworkAuth()
        
        guard let URLAsString = downloadAt.absoluteString.replacingOccurrences(of: "file://", with: "").removingPercentEncoding else {
            throw BackupError.invalidDownloadURL
        }
        
        guard let networkAuthUnwrapped = networkAuth else {
            throw BackupError.missingNetworkAuth
        }
        
        xpcBackupService.downloadFileBackup(
            downloadAt: URLAsString,
            networkAuth: networkAuthUnwrapped,
            fileId:fileId,
            bucketId: deviceBucketId,
            with: {result, error in
                if error == nil {
                    DispatchQueue.main.async {
                        self.removeItem(item: itemBackup)
                        
                    }
                    self.logger.info("Backup file downloaded✅")
                    
                } else {
                    self.removeItem(item: itemBackup)
                    self.logger.info("Error to download file \(error ?? "Unknown Error")")
                }
            }
        )
    }

    func stopBackupUpload() throws {
        logger.debug("Going to stop backup upload")
        DispatchQueue.main.async {
            self.backupUploadStatus = .Idle
        }
        
        xpcBackupService?.stopBackupUpload()
    }
    
    func stopBackupDownload() throws {
        logger.debug("Going to stop backup download")
        DispatchQueue.main.async {
            self.backupDownloadStatus = .Idle
        }
        
        xpcBackupService?.stopBackupDownload()
    }
    
    private func getXPCBackupServiceProtocol(onConnectionIssue: @escaping () -> Void) async throws -> XPCBackupServiceProtocol {
        if let service = self.xpcBackupService {
            return service
        }
        return try await withCheckedThrowingContinuation{continuation in
            let connectionToService = NSXPCConnection(serviceName: "com.internxt.XPCBackupService")
            connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
            connectionToService.interruptionHandler = {
                appLogger.error("Connection with XPCBackupsService interrupted")
                onConnectionIssue()
            }
            connectionToService.invalidationHandler = {
                appLogger.error("Connection with XPCBackupsService interrupted")
                onConnectionIssue()
            }
            connectionToService.resume()

            
            guard let service = connectionToService.remoteObjectProxyWithErrorHandler({ error in
                continuation.resume(throwing: error)
            }) as? XPCBackupServiceProtocol else {
                return continuation.resume(throwing: BackupError.cannotInitializeXPCService)
            }
            
            self.xpcBackupService = service
            
            continuation.resume(returning: service)
        }
        
    }
             
    private func checkBackupUploadProgress() {
        self.logger.info("Getting progress")
        self.xpcBackupService?.getBackupUploadStatus{backupStatusUpdate, error in
            
            guard let backupStatus = backupStatusUpdate else {
                return
            }
            
            self.logger.info(["Backup status update received", backupStatus.totalSyncs, backupStatus.status])
            
            if(backupStatus.totalSyncs == 0) {
                return
            }
            
            DispatchQueue.main.async {
                
                self.backupUploadStatus = backupStatus.status
                self.backupUploadProgress = backupStatus.progress
                self.logger.info(["Backup upload is in \(backupStatus.status) status, \(backupStatus.completedSyncs) of \(backupStatus.totalSyncs) nodes synced, \(self.backupUploadProgress * 100)% synced"])
            }
            
            if(backupStatus.status == .Done || backupStatus.status == .Failed) {
                
                self.backupUploadProgressTimer?.cancel()
            }
        }
    }
    
    private func checkBackupDownloadProgress(xpcBackupService: XPCBackupServiceProtocol) {
        self.logger.info("Getting download backup progress")
        xpcBackupService.getBackupDownloadStatus{backupStatusUpdate, error in

            guard let backupDownloadStatus = backupStatusUpdate else {
                return
            }
            
            DispatchQueue.main.async {
                if self.backupDownloadStatus != .Done {
                    self.backupDownloadStatus = backupDownloadStatus.status
                }
                self.backupDownloadedItems = backupDownloadStatus.completedSyncs
                self.logger.info("Backup download is in \(backupDownloadStatus.status) status, \(backupDownloadStatus.completedSyncs) items downloaded")
            }
            
            if(backupDownloadStatus.status == .Done || backupDownloadStatus.status == .Failed) {
                self.backupDownloadProgressTimer?.cancel()
            }
        }
    }
    
    private func completeBackupDownload() {
        self.backupDownloadProgressTimer?.cancel()
        Task {
            guard let deviceDownloading = self.deviceDownloading else {
                return
            }
            let activityEntry = ActivityEntry(filename: "Backup — “\(deviceDownloading.plainName ?? String(deviceDownloading.id))”", kind: .backupDownload, status: .finished)
            self.activityManager.saveActivityEntry(entry: activityEntry)
        }
        
    }
    
    private func removeItem(item: ItemBackup){
        if let index = backupsItemsInprogress.firstIndex(where: { $0.id == item.id }) {
            backupsItemsInprogress.remove(at: index)
        }
    }
    
    private func showAlert() {
        DispatchQueue.main.async {
            NSAlert.showStorageFullAlert()
        }
    }

    @MainActor
    func fetchBackupStatus() async {
        do {
            
            let paymentInfo = try await APIFactory.Payment.getPaymentInfo()
            guard let backupStatus = paymentInfo.featuresPerService.backups else {
                appLogger.error("No backup information")

                return
            }
            self.currentBackupState  = backupStatus ? .active : .locked
            if !backupStatus {
                removeScheduledBackup()
            }
        }
        catch {
            
            guard let apiError = error as? APIClientError else {
                appLogger.info(error.getErrorDescription())
                return
            }
            appLogger.info(error.getErrorDescription())
            if(apiError.statusCode == 404) {
                removeScheduledBackup()
               self.currentBackupState = .locked
            }
        }
    }
    
    private func removeScheduledBackup() {
        UserDefaults.standard.removeObject(forKey: LAST_BACKUP_TIME_KEY)

    }
}



class FolderToBackup {
    var name: String
    var type: String
    var id: String
    let url: URL
    let status: FolderToBackupStatus
    let createdAt: Date
    
    
    init(folderToBackupRealmObject: FolderToBackupRealmObject) {
        self.id = folderToBackupRealmObject.id
        self.url = URL(fileURLWithPath: folderToBackupRealmObject.url.removingPercentEncoding?.replacingOccurrences(of: "file://", with: "") ?? "")
        self.status = folderToBackupRealmObject.status
        self.createdAt = folderToBackupRealmObject.createdAt
        self.name = self.url.lastPathComponent.removingPercentEncoding ?? "Unknown folder"
        self.type = (self.name as NSString).pathExtension
    }
    
    init(id: String,url: URL, status: FolderToBackupStatus, createdAt: Date) {
        self.id = id
        self.url = url
        self.status = status
        self.createdAt = createdAt
        self.name = self.url.lastPathComponent.removingPercentEncoding ?? "Unknown folder"
        self.type = (self.name as NSString).pathExtension
    }
    
    
    
    
    func folderIsMissing() -> Bool {
        var isDirectory: ObjCBool = true
        return !FileManager.default.fileExists(atPath: self.url.path, isDirectory: &isDirectory)
    }
}


class FolderToBackupRealmObject: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var url: String
    @Persisted var status: FolderToBackupStatus
    @Persisted var createdAt: Date

    convenience init(
        url: URL,
        status: FolderToBackupStatus
    ) {
        self.init()
        self.url = url.absoluteString
        self.createdAt = Date()
        self.status = status
    }
}

extension FolderToBackupRealmObject {
    func clone() -> FolderToBackupRealmObject {
        let clonedObject = FolderToBackupRealmObject()
        clonedObject.url = self.url
        clonedObject.status = self.status
        clonedObject.createdAt = self.createdAt
        return clonedObject
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
