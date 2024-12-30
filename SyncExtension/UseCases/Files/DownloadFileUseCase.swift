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
    
    
    

 
    public func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        
        Task {
           
          
            do {
                
                func progressHandler(completedProgress: Double) {
                    let progressPercentage = completedProgress * 100
                    progress.completedUnitCount = Int64(progressPercentage)
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
 
                self.logger.info("Fetching file \(fileProviderItem.itemIdentifier.rawValue) inside of \(fileProviderItem.parentItemIdentifier.rawValue)")
                
                completionHandler(decryptedFileURL, fileProviderItem , nil)

                progressHandler(completedProgress: 1)
                let uuidString = fileProviderItem.itemIdentifier.rawValue.replacingOccurrences(of: "-", with: "").prefix(24)
                let objectId = try ObjectId(string: String(uuidString))
                activityManager.saveActivityEntry(entry: ActivityEntry(_id: objectId, filename: filename, kind: .download, status: .finished))
                self.logger.info("✅ Downloaded and decrypted file correctly with identifier \(itemIdentifier.rawValue)")
            } catch {

                error.reportToSentry()
                self.logger.error("❌ Failed to fetch file content for file with identifier \(itemIdentifier.rawValue): \(error.getErrorDescription())")
                
                completionHandler(nil, nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue))
            }
        }
        
        return progress
    }
}
