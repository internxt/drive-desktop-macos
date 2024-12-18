//
//  GetFileOrFolderMetaWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 10/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore



struct GetFileOrFolderMetaWorkspaceUseCase {
    let logger = syncExtensionWorkspaceLogger
    private let driveNewAPI: DriveAPI = APIFactory.DriveWorkspace
    private let completionHandler: (NSFileProviderItem?, Error?) -> Void
    private let identifier: NSFileProviderItemIdentifier
    private let user: DriveUser
    private let workspace: [AvailableWorkspace]

    init(user: DriveUser,identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?
    ) -> Void  , workspace : [AvailableWorkspace]) {
        self.completionHandler = completionHandler
        self.identifier = identifier
        self.user = user
        self.workspace = workspace
    }
    
    public func run() -> Progress {
        
        Task {
            do {
                var itemFound = false
                self.logger.info("Trying to get metadata for item \(self.identifier.rawValue) as a file")
                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    throw GetFileOrFolderMetaUseCaseError.InvalidWorkspace
                }

                let rootFolderUuid = workspace[0].workspaceUser.rootFolderId
               
                if let fileMeta = await self.getFileMetaOrNil(maybeFileUuid: self.identifier.rawValue) {
                    
                    guard let folderUuid = fileMeta.folderUuid else {
                        
                        self.logger.error("Cannot get folderUuid from \(self.identifier.rawValue)")
                        throw GetFileOrFolderMetaUseCaseError.FileOrFolderMetaUuidNotFound
                    }
                    let parentIsRootContainer = folderUuid == rootFolderUuid
                    guard let createdAt = Time.dateFromISOString(fileMeta.createdAt) else {
                        self.logger.error("Cannot create createdAt date for file \(fileMeta.id) with value \(fileMeta.createdAt)")
                        throw GetFileOrFolderMetaUseCaseError.InvalidCreatedAt
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for file \(fileMeta.id) with value \(fileMeta.updatedAt)")
                        throw GetFileOrFolderMetaUseCaseError.InvalidUpdatedAt
                    }
                    
                    guard let sizeInt = Int(fileMeta.size) else {
                        self.logger.error("Cannot get size for file \(fileMeta.id) with size value \(fileMeta.size)")
                        throw GetFileOrFolderMetaUseCaseError.InvalidSize
                    }
                    
                    let fileItem = FileProviderItem(
                        identifier: self.identifier,
                        // TODO: Decrypt the name if needed
                        filename: FileProviderItem.getFilename(name: fileMeta.plainName ?? fileMeta.name, itemExtension: fileMeta.type)
                        ,
                        parentId: parentIsRootContainer ? .rootContainer : NSFileProviderItemIdentifier(rawValue: folderUuid),
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: fileMeta.type,
                        itemType: .file,
                        size:sizeInt
                    )
                    
                    completionHandler(fileItem, nil)
                    self.logger.info("✅ Got metadata for file with name \(fileMeta.plainName ?? fileMeta.name) and id \(self.identifier.rawValue)")
                    itemFound = true
                }
                if (itemFound == true){ return }
                
                self.logger.info("Trying to get metadata for item \(self.identifier.rawValue) as a folder")
                if let folderMeta = await self.getFolderMetaOrNil(maybeFolderId: self.identifier.rawValue) {
                    guard let createdAt = Time.dateFromISOString(folderMeta.createdAt) else {
                        self.logger.error("Cannot create createdAt date for folder \(folderMeta.id) with value \(folderMeta.createdAt)")
                        throw GetFileOrFolderMetaUseCaseError.InvalidCreatedAt
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(folderMeta.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for file \(folderMeta.id) with value \(folderMeta.updatedAt)")
                        throw GetFileOrFolderMetaUseCaseError.InvalidUpdatedAt
                    }
                    
                    var parentId: NSFileProviderItemIdentifier = .rootContainer
                    
                    if folderMeta.parentUuid != nil {
                        parentId = NSFileProviderItemIdentifier(String(folderMeta.parentUuid!))
                    }
                    
                    
                    let folderItem = FileProviderItem(
                        identifier: self.identifier,
                        // TODO: Decrypt the name if needed
                        filename: folderMeta.plainName ?? folderMeta.name,
                        parentId: parentId,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: nil,
                        itemType: .folder
                    )
                    
                    
                    completionHandler(folderItem, nil)
                    self.logger.info("✅ Got metadata for folder with name \(folderItem.filename)")
                    itemFound = true
                }
                if (itemFound == true){ return }
                // If we reached this, there was no way to found the file/folder
                throw GetFileOrFolderMetaUseCaseError.FileOrFolderMetaNotFound
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to get folder meta for \(identifier.rawValue): \(error.getErrorDescription())")
                completionHandler(nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
    
    private func getFileMetaOrNil(maybeFileUuid: String) async -> GetFileMetaByIdResponse? {
        do {
            let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: maybeFileUuid,debug: true)
            
            if fileMeta.uuid != maybeFileUuid {
                return nil
            }
            return fileMeta
        } catch {
            guard let apiError = error as? APIClientError else {
                // This is not an APIError, report it
                error.reportToSentry()
                return nil
            }
            // If this is a 400, ignore the error, this is not a file
            if apiError.statusCode != 400 {
                apiError.reportToSentry()
            }
            
            return nil
        }
    }
    
    private func getFolderMetaOrNil(maybeFolderId: String) async -> GetFolderMetaByIdResponse? {
        do {
            return try await driveNewAPI.getFolderMetaByUuid(uuid: maybeFolderId,debug: true)
        } catch {
            guard let apiError = error as? APIClientError else {
                // This is not an APIError, report it
                error.reportToSentry()
                return nil
            }
            // If this is a 404, folder not found, ignore the error, we tried
            if apiError.statusCode != 404 {
                apiError.reportToSentry()
            }
            
            return nil
        }
    }
}
