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
    
    
    



 
    public func run() -> Progress {
        let progress = Progress(totalUnitCount: 100)
        
        
        Task {
           
          
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
                
                self.logger.info("Fetching file \(fileProviderItem.itemIdentifier.rawValue) inside of \(fileProviderItem.parentItemIdentifier.rawValue)")
                
                completionHandler(decryptedFileURL, fileProviderItem , nil)

                progressHandler(completedProgress: 1)
                let uuidString = fileProviderItem.itemIdentifier.rawValue.replacingOccurrences(of: "-", with: "").prefix(24)
                let objectId = try ObjectId(string: String(uuidString))
                activityManager.saveActivityEntry(entry: ActivityEntry(_id: objectId, filename: filename + "- Workspace", kind: .download, status: .finished))
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
