//
//  FetchFileContentUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import RealmSwift


enum DownloadFileUseCaseError: Error {
    case DriveFileMissing
}

struct DownloadFileUseCase {
    let logger = syncExtensionLogger
    private let cryptoUtils = CryptoUtils()
    private let networkFacade: NetworkFacade
    private let completionHandler: (URL?, NSFileProviderItem?, Error?) -> Void
    private let driveNewAPI = APIFactory.DriveNew
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let destinationURL: URL
    private let encryptedFileDestinationURL: URL
    private let itemIdentifier: NSFileProviderItemIdentifier
    private let activityManager: ActivityManager
    init(networkFacade: NetworkFacade,
         user: DriveUser,
         activityManager: ActivityManager,
         itemIdentifier: NSFileProviderItemIdentifier,
         encryptedFileDestinationURL: URL,
         destinationURL: URL,
         completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void
    ) {
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
        self.destinationURL = destinationURL
        self.itemIdentifier = itemIdentifier
        self.encryptedFileDestinationURL = encryptedFileDestinationURL
        self.activityManager = activityManager
    }
    
    
    
    private func trackStart(driveFile: DriveFile, processIdentifier: String) -> Date {
        let event = DownloadStartedEvent(
            fileName: driveFile.name,
            fileExtension: driveFile.type ?? "",
            fileSize: Int64(driveFile.size),
            fileUuid: driveFile.uuid,
            fileId: driveFile.fileId,
            parentFolderId: driveFile.folderId
        )
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
        
        return Date()
    }
    
    private func trackEnd(driveFile: DriveFile, processIdentifier: String, startedAt: Date) {

        let event = DownloadCompletedEvent(
            fileName: driveFile.name,
            fileExtension: driveFile.type ?? "",
            fileSize: Int64(driveFile.size),
            fileUuid: driveFile.uuid,
            fileId: driveFile.fileId,
            parentFolderId: driveFile.folderId,
            elapsedTimeMs: Date().timeIntervalSince(startedAt) * 1000
        )
        
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }
    
    private func trackError(driveFile: DriveFile,processIdentifier: String, error: any Error) {
        let event = DownloadErrorEvent(
            fileName: driveFile.name,
            fileExtension: driveFile.type ?? "",
            fileSize: Int64(driveFile.size),
            fileUuid: driveFile.uuid,
            fileId: driveFile.fileId,
            parentFolderId: driveFile.folderId,
            error: error
        )
        
        DispatchQueue.main.async {
            Analytics.shared.track(event: event)
        }
    }
 
    public func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        
        Task {
           
            var driveFile: DriveFile? = nil
            do {
                
                func progressHandler(completedProgress: Double) {
                    let progressPercentage = completedProgress * 100
                    progress.completedUnitCount = Int64(progressPercentage)
                }
                self.logger.info("⬇️ Fetching file \(itemIdentifier.rawValue)")
                let file = try await driveNewAPI.getFileMetaByUuid(uuid: itemIdentifier.rawValue)
                
                driveFile = DriveFile(
                    uuid: file.uuid,
                    plainName: file.plainName,
                    name: file.name,
                    type: file.type,
                    size: Int(file.size) ?? 0,
                    createdAt: Time.dateFromISOString(file.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(file.updatedAt) ?? Date(),
                    folderId: file.folderId,
                    status: DriveItemStatus(rawValue: file.status) ?? DriveItemStatus.exists,
                    fileId: file.fileId
                )
                
            
                guard let driveFileUnrawpped = driveFile else {
                    throw DownloadFileUseCaseError.DriveFileMissing
                }
                let trackStartedAt = trackStart(driveFile: driveFileUnrawpped, processIdentifier: driveFileUnrawpped.uuid)
                let decryptedFileURL = try await networkFacade.downloadFile(
                    bucketId: file.bucket,
                    fileId: file.fileId,
                    encryptedFileDestination: encryptedFileDestinationURL,
                    destinationURL: destinationURL,
                    progressHandler: { completedProgress in
                        let maxProgress = 0.99
                        progressHandler(completedProgress: completedProgress * maxProgress)
                    },
                    debug: true
                )
                
                
                
                let filename = FileProviderItem.getFilename(name: file.plainName ?? file.name, itemExtension: file.type)
                let parentIsRootFolder = file.folderId == user.root_folder_id
                let fileProviderItem = FileProviderItem(
                    identifier: itemIdentifier,
                    filename: filename,
                    parentId: parentIsRootFolder ? .rootContainer : NSFileProviderItemIdentifier(rawValue: String(file.folderId)),
                    createdAt: Time.dateFromISOString(file.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(file.updatedAt) ?? Date(),
                    itemExtension: file.type,
                    itemType: .file,
                    size: Int(file.size)!
                )
                
                trackEnd(driveFile: driveFileUnrawpped, processIdentifier: driveFileUnrawpped.uuid, startedAt: trackStartedAt)
                self.logger.info("Fetching file \(fileProviderItem.itemIdentifier.rawValue) inside of \(fileProviderItem.parentItemIdentifier.rawValue)")
                
                completionHandler(decryptedFileURL, fileProviderItem , nil)

                progressHandler(completedProgress: 1)
                let uuidString = fileProviderItem.itemIdentifier.rawValue.replacingOccurrences(of: "-", with: "").prefix(24)
                let objectId = try ObjectId(string: String(uuidString))
                activityManager.saveActivityEntry(entry: ActivityEntry(_id: objectId, filename: filename, kind: .download, status: .finished))
                self.logger.info("✅ Downloaded and decrypted file correctly with identifier \(itemIdentifier.rawValue)")
            } catch {
                if let driveFileUnwrapped = driveFile {
                    trackError(driveFile: driveFileUnwrapped, processIdentifier: driveFileUnwrapped.uuid, error: error)
                }
                error.reportToSentry()
                self.logger.error("❌ Failed to fetch file content for file with identifier \(itemIdentifier.rawValue): \(error.getErrorDescription())")
                
                completionHandler(nil, nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue))
            }
        }
        
        return progress
    }
}
