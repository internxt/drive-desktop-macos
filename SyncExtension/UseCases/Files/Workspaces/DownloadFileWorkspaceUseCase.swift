//
//  DownloadFileWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import RealmSwift

struct DownloadFileWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    private let cryptoUtils = CryptoUtils()
    private let networkFacade: NetworkFacade
    private let completionHandler: (URL?, NSFileProviderItem?, Error?) -> Void
    private let driveNewAPI = APIFactory.DriveNew
    private let driveNewAPIWorkspace = APIFactory.DriveWorkspace
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let destinationURL: URL
    private let encryptedFileDestinationURL: URL
    private let itemIdentifier: NSFileProviderItemIdentifier
    private let activityManager: ActivityManager
    private let workspace: [AvailableWorkspace]

    init(networkFacade: NetworkFacade,
         user: DriveUser,
         activityManager: ActivityManager,
         itemIdentifier: NSFileProviderItemIdentifier,
         encryptedFileDestinationURL: URL,
         destinationURL: URL,
         completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void ,
         workspace: [AvailableWorkspace]
    ) {
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
        self.destinationURL = destinationURL
        self.itemIdentifier = itemIdentifier
        self.encryptedFileDestinationURL = encryptedFileDestinationURL
        self.activityManager = activityManager
        self.workspace = workspace
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

                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    return
                }

                let rootFolderUuid = workspace[0].workspaceUser.rootFolderId
                
                let file = try await driveNewAPIWorkspace.getFileMetaByUuid(uuid: itemIdentifier.rawValue)
                
                guard let folderUuid = file.folderUuid else {
                    self.logger.error("FolderUuid dont exists")
                    return
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
                let parentIsRootFolder = folderUuid == rootFolderUuid
                let fileProviderItem = FileProviderItem(
                    identifier: itemIdentifier,
                    filename: filename,
                    parentId: parentIsRootFolder ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folderUuid),
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
                activityManager.saveActivityEntry(entry: ActivityEntry(_id: objectId, filename: filename + "- Workspace", kind: .download, status: .finished))
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
