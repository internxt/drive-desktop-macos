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
    private let maxRetries: Int = 3
    private let baseRetryDelay: TimeInterval = 1.0
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
    
    
    
    private func shouldRetry(error: Error) -> Bool {
      
        if let apiError = error as? APIClientError {
            let statusCode = apiError.statusCode
            // Don't retry: 400 errors
            if statusCode >= 400 && statusCode < 500 {
                return false
            }
            return true
        }
        return true
    }
    
    private func getFileMetaWithRetry(
        uuid: String,
        maxRetries: Int,
        currentAttempt: Int = 1
    ) async throws -> GetFileMetaByIdResponseV2 {
        do {
            return try await driveNewAPI.getFileMetaByUuidV2(uuid: uuid)
        } catch {
            if currentAttempt < maxRetries && shouldRetry(error: error) {
                let delay = baseRetryDelay * pow(2.0, Double(currentAttempt - 1))
                self.logger.warning("⚠️ Failed to get file metadata for \(uuid) (attempt \(currentAttempt)). Retrying in \(delay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await getFileMetaWithRetry(
                    uuid: uuid,
                    maxRetries: maxRetries,
                    currentAttempt: currentAttempt + 1
                )
            } else {
                if currentAttempt >= maxRetries {
                    self.logger.error("❌ All retry attempts failed to get file metadata for \(uuid) after \(maxRetries) attempts")
                }
                throw error
            }
        }
    }
    
    private func downloadWithRetry(
        file: GetFileMetaByIdResponseV2,
        progress: Progress,
        progressHandler: @escaping (Double) -> Void,
        maxRetries: Int,
        currentAttempt: Int = 1
    ) async throws -> URL {
        do {
            guard let fileId = file.fileId else {
                throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.noSuchItem.rawValue, userInfo: [NSLocalizedDescriptionKey: "File ID is missing"])
            }
            
            return try await networkFacade.downloadFile(
                bucketId: file.bucket,
                fileId: fileId,
                encryptedFileDestination: encryptedFileDestinationURL,
                destinationURL: destinationURL,
                progressHandler: { completedProgress in
                    let maxProgress = 0.99
                    progressHandler(completedProgress * maxProgress)
                },
                debug: true
            )
        } catch {
            if currentAttempt < maxRetries {
                let delay = baseRetryDelay * pow(2.0, Double(currentAttempt - 1))
                self.logger.warning("⚠️ Attempt \(currentAttempt) failed for \(itemIdentifier.rawValue). Retrying in \(delay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                return try await downloadWithRetry(
                    file: file,
                    progress: progress,
                    progressHandler: progressHandler,
                    maxRetries: maxRetries,
                    currentAttempt: currentAttempt + 1
                )
            } else {
                self.logger.error("❌ All retry attempts failed for \(itemIdentifier.rawValue) after \(maxRetries) attempts")
                throw error
            }
        }
    }
 
    public func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        
        Task {
           
            let uuidString = itemIdentifier.rawValue.replacingOccurrences(of: "-", with: "").prefix(24)
            let trackingObjectId = try? ObjectId(string: String(uuidString))
            
            var driveFile: DriveFile? = nil
            do {
                
                func progressHandler(completedProgress: Double) {
                    let progressPercentage = completedProgress * 100
                    progress.completedUnitCount = Int64(progressPercentage)
                }
                self.logger.info("⬇️ Fetching file \(itemIdentifier.rawValue)")
                
                let idString = itemIdentifier.rawValue
                let isUUID = UUID(uuidString: idString) != nil
                
                if !isUUID {
            
                    let folder = try await driveNewAPI.getFolderMetaById(id: idString)
                    let folderName = folder.plainName ?? folder.name ?? ""
                    
                    if let trackingObjectId = trackingObjectId {
                        activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: folderName, kind: .download, status: .inProgress)
                    }
                    
                    try await downloadFolderIteratively(
                        initialFolderUuid: folder.uuid!,
                        localFolderURL: destinationURL
                    )
                    
                    let parentIsRootFolder = folder.parentId == nil || folder.parentId == user.root_folder_id
                    let parentId: NSFileProviderItemIdentifier = parentIsRootFolder ? .rootContainer : NSFileProviderItemIdentifier(String(folder.parentId!))
                    
                    let fileProviderItem = FileProviderItem(
                        identifier: itemIdentifier,
                        filename: folderName,
                        parentId: parentId,
                        createdAt: Time.dateFromISOString(folder.createdAt) ?? Date(),
                        updatedAt: Time.dateFromISOString(folder.updatedAt) ?? Date(),
                        itemExtension: (folderName as NSString).pathExtension,
                        itemType: .file,
                        size: 0
                    )
                    
                    completionHandler(destinationURL, fileProviderItem, nil)
                    progressHandler(completedProgress: 1)
                    
                    if let trackingObjectId = trackingObjectId {
                        activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: folderName, kind: .download, status: .finished)
                    }
                    
                    return
                }
                
                let file = try await getFileMetaWithRetry(uuid: idString, maxRetries: maxRetries)
                
                guard let file = Optional.some(file) else {
                    throw DownloadFileUseCaseError.DriveFileMissing
                }
                
                let currentFilename = FileProviderItem.getFilename(name: file.plainName ?? file.name, itemExtension: file.type)
                if let trackingObjectId = trackingObjectId {
                    activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: currentFilename, kind: .download, status: .inProgress)
                }
                
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
                    fileId: file.fileId ?? ""
                )
                
            
                guard driveFile != nil else {
                    throw DownloadFileUseCaseError.DriveFileMissing
                }

                if Int(file.size) ?? 0 == 0 {
                    self.logger.info("⚠️ File \(itemIdentifier.rawValue) has size 0, skipping download")
                    
                    
                    FileManager.default.createFile(atPath: destinationURL.path, contents: nil, attributes: nil)
                    
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
                        size: 0
                    )
                    
                    completionHandler(destinationURL, fileProviderItem, nil)
                    progressHandler(completedProgress: 1)
                    
                    if let trackingObjectId = trackingObjectId {
                        activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: filename, kind: .download, status: .finished)
                    }
                    
                    self.logger.info("✅ Created empty file with identifier \(itemIdentifier.rawValue)")
                    return
                }
                
                let decryptedFileURL = try await downloadWithRetry(
                    file: file,
                    progress: progress,
                    progressHandler: progressHandler,
                    maxRetries: maxRetries
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
                
   
                self.logger.info("Fetching file \(fileProviderItem.itemIdentifier.rawValue) inside of \(fileProviderItem.parentItemIdentifier.rawValue)")
                
                completionHandler(decryptedFileURL, fileProviderItem , nil)

                progressHandler(completedProgress: 1)
                if let trackingObjectId = trackingObjectId {
                    activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: filename, kind: .download, status: .finished)
                }
                self.logger.info("✅ Downloaded and decrypted file correctly with identifier \(itemIdentifier.rawValue)")
            } catch {
          
                error.reportToSentry()
                self.logger.error("❌ Failed to fetch file content for file with identifier \(itemIdentifier.rawValue): \(error.getErrorDescription())")
                
                if let trackingObjectId = trackingObjectId {
                    activityManager.updateActivityEntryStatus(id: trackingObjectId, filename: itemIdentifier.rawValue, kind: .download, status: .failed, errorMessage: error.getErrorDescription())
                }
                completionHandler(nil, nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue))
            }
        }
        
        return progress
    }
    

    
    private func downloadFilesInDirectory(folderUuid: String, localFolderURL: URL) async throws {
        var fileOffset = 0
        let limit = 50
        var hasMoreFiles = true
        
        while hasMoreFiles {
            let filesResponse = try await driveNewAPI.getFolderFilesV2(folderUuid: folderUuid, offset: fileOffset, limit: limit)
            
            for file in filesResponse.files {
                let filename = FileProviderItem.getFilename(name: file.plainName ?? file.name ?? "", itemExtension: file.type)
                let localFileURL = localFolderURL.appendingPathComponent(filename)
                
                let encryptedFileDestination = localFolderURL.appendingPathComponent("enc-\(UUID().uuidString).enc")
                
                defer {
                    try? FileManager.default.removeItem(at: encryptedFileDestination)
                }
                
                _ = try await networkFacade.downloadFile(
                    bucketId: file.bucket,
                    fileId: file.fileId ?? "",
                    encryptedFileDestination: encryptedFileDestination,
                    destinationURL: localFileURL,
                    progressHandler: { _ in },
                    debug: true
                )
            }
            
            if filesResponse.files.count < limit {
                hasMoreFiles = false
            } else {
                fileOffset += limit
            }
        }
    }
    
    private func downloadFolderIteratively(initialFolderUuid: String, localFolderURL: URL) async throws {
        struct FolderDownloadTask {
            let uuid: String
            let localURL: URL
        }
        
        var queue: [FolderDownloadTask] = [FolderDownloadTask(uuid: initialFolderUuid, localURL: localFolderURL)]
        
        while !queue.isEmpty {
            let currentTask = queue.removeFirst()
            try FileManager.default.createDirectory(at: currentTask.localURL, withIntermediateDirectories: true)
            
        
            try await downloadFilesInDirectory(folderUuid: currentTask.uuid, localFolderURL: currentTask.localURL)
            
            var folderOffset = 0
            let limit = 50
            var hasMoreFolders = true
            
            while hasMoreFolders {
                let foldersResponse = try await driveNewAPI.getFolderFolders(folderUuid: currentTask.uuid, offset: folderOffset, limit: limit)
                
                for subFolder in foldersResponse.folders {
                    let name = subFolder.plainName ?? subFolder.name
                    let localSubFolderURL = currentTask.localURL.appendingPathComponent(name)
                    queue.append(FolderDownloadTask(uuid: subFolder.uuid ?? "", localURL: localSubFolderURL))
                }
                
                if foldersResponse.folders.count < limit {
                    hasMoreFolders = false
                } else {
                    folderOffset += limit
                }
            }
        }
    }
}
