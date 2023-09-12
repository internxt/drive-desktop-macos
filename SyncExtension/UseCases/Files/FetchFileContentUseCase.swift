//
//  FetchFileContentUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import os.log
import FileProvider
import InternxtSwiftCore


struct FetchFileContentUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "FetchFileContent")
    private let cryptoUtils = CryptoUtils()
    private let networkFacade: NetworkFacade
    private let completionHandler: (URL?, NSFileProviderItem?, Error?) -> Void
    private let driveNewAPI = APIFactory.DriveNew
    private let config = ConfigLoader().get()
    private let user: DriveUser
    private let destinationURL: URL
    private let encryptedFileDestinationURL: URL
    private let itemIdentifier: NSFileProviderItemIdentifier
    
    init(networkFacade: NetworkFacade, user: DriveUser, itemIdentifier: NSFileProviderItemIdentifier, encryptedFileDestinationURL: URL, destinationURL: URL, completionHandler: @escaping (URL?, NSFileProviderItem?, Error?) -> Void) {
        self.completionHandler = completionHandler
        self.networkFacade = networkFacade
        self.user = user
        self.destinationURL = destinationURL
        self.itemIdentifier = itemIdentifier
        self.encryptedFileDestinationURL = encryptedFileDestinationURL
    }
 
    public func run() -> Progress {
        
        let progress = Progress(totalUnitCount: 100)
        
        Task {
            do {
                
                func progressHandler(completedProgress: Double) {
                    let progressPercentage = completedProgress * 100
                    progress.completedUnitCount = Int64(progressPercentage)
                    //let progressStr =  String(format: "%.1f", progressPercentage)
                    //self.logger.info("⬇️ Downloading file \(file.plainName ?? file.name)...\(progressStr)%")
                }
                self.logger.info("⬇️ Fetching file \(itemIdentifier.rawValue)")
                let file = try await driveNewAPI.getFileMetaByUuid(uuid: itemIdentifier.rawValue)
                let decryptedFileURL = try await networkFacade.downloadFile(
                    bucketId: file.bucket,
                    fileId: file.fileId,
                    encryptedFileDestination: encryptedFileDestinationURL,
                    destinationURL: destinationURL,
                    progressHandler: { completedProgress in
                        let maxProgress = 0.99
                        progressHandler(completedProgress: completedProgress * maxProgress)
                    }
                )
                
                let parentIsRootFolder = file.folderId == user.root_folder_id
                let fileProviderItem = FileProviderItem(
                    identifier: itemIdentifier,
                    filename: FileProviderItem.getFilename(name: file.plainName ?? file.name, itemExtension: file.type),
                    parentId: parentIsRootFolder ? .rootContainer : NSFileProviderItemIdentifier(rawValue: String(file.folderId)),
                    createdAt: Time.dateFromISOString(file.createdAt) ?? Date(),
                    updatedAt: Time.dateFromISOString(file.updatedAt) ?? Date(),
                    itemExtension: file.type,
                    itemType: .file,
                    size: Int(file.size)!
                )
                
                self.logger.info("Fetching file \(fileProviderItem.itemIdentifier.rawValue) inside of \(fileProviderItem.parentItemIdentifier.rawValue)")
                
                completionHandler(decryptedFileURL, fileProviderItem , nil)
                // Finish
                progressHandler(completedProgress: 1)
                self.logger.info("✅ Downloaded and decrypted file correctly with identifier \(itemIdentifier.rawValue)")
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to fetch file content: \(error.localizedDescription)")
                completionHandler(nil, nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return progress
    }
}
