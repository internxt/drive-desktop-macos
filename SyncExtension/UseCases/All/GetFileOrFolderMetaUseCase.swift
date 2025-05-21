//
//  GetFileOrFolderMetaUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

enum GetFileOrFolderMetaUseCaseError: Error {
    case InvalidItemId
    case InvalidSize
    case InvalidCreatedAt
    case InvalidUpdatedAt
    case FileOrFolderMetaNotFound
    case FileOrFolderMetaUuidNotFound
    case InvalidWorkspace
}


struct GetFileOrFolderMetaUseCase {
    let logger = syncExtensionLogger
    private let driveAPI: DriveAPI = APIFactory.Drive
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let completionHandler: (NSFileProviderItem?, Error?) -> Void
    private let identifier: NSFileProviderItemIdentifier
    private let user: DriveUser
    init(user: DriveUser,identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        self.completionHandler = completionHandler
        self.identifier = identifier
        self.user = user
    }
    
    public func run() -> Progress {
        Task {
            do {
                let identifierRaw = self.identifier.rawValue

                if UUID(uuidString: identifierRaw) != nil {
                    // File
                    self.logger.info("👽 Is file UUID (\(identifierRaw))")
                    self.logger.info("Trying to get metadata for item \(identifierRaw) as a file")
                    if let fileMeta = await self.getFileMetaOrNil(maybeFileUuid: identifierRaw) {
                        let parentFolderId = String(fileMeta.folderId)
                        
                        if let parentMeta = await self.getFolderMetaOrNil(maybeFolderId: parentFolderId),
                           parentMeta.deleted == true {
                            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: self.identifier))
                            return
                        }

                        let parentIsRootContainer = fileMeta.folderId == user.root_folder_id

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
                            filename: FileProviderItem.getFilename(name: fileMeta.plainName ?? fileMeta.name, itemExtension: fileMeta.type),
                            parentId: parentIsRootContainer ? .rootContainer : NSFileProviderItemIdentifier(rawValue: parentFolderId),
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            itemExtension: fileMeta.type,
                            itemType: .file,
                            size: sizeInt
                        )

                        completionHandler(fileItem, nil)
                        self.logger.info("✅ Got metadata for file with name \(fileMeta.plainName ?? fileMeta.name) and id \(identifierRaw)")
                        return
                    }
                } else {
                    // Folder
                    self.logger.info(" ✌🏻Is folder identifier (\(identifierRaw))")

                    self.logger.info("Trying to get metadata for item \(identifierRaw) as a folder")
                    if let folderMeta = await self.getFolderMetaOrNil(maybeFolderId: identifierRaw) {
                        if let parentId = folderMeta.parentId,
                           let parentMeta = await self.getFolderMetaOrNil(maybeFolderId: String(parentId)),
                           parentMeta.deleted == true {
                            self.logger.info("Parent folder \(parentId) of item \(identifierRaw) is deleted")
                            completionHandler(nil, NSError.fileProviderErrorForNonExistentItem(withIdentifier: self.identifier))
                            return
                        }

                        guard let createdAt = Time.dateFromISOString(folderMeta.createdAt) else {
                            self.logger.error("Cannot create createdAt date for folder \(folderMeta.id) with value \(folderMeta.createdAt)")
                            throw GetFileOrFolderMetaUseCaseError.InvalidCreatedAt
                        }

                        guard let updatedAt = Time.dateFromISOString(folderMeta.updatedAt) else {
                            self.logger.error("Cannot create updatedAt date for folder \(folderMeta.id) with value \(folderMeta.updatedAt)")
                            throw GetFileOrFolderMetaUseCaseError.InvalidUpdatedAt
                        }

                        let parentId = folderMeta.parentId.map { NSFileProviderItemIdentifier(String($0)) } ?? .rootContainer

                        let folderItem = FileProviderItem(
                            identifier: self.identifier,
                            filename: folderMeta.plainName ?? folderMeta.name,
                            parentId: parentId,
                            createdAt: createdAt,
                            updatedAt: updatedAt,
                            itemExtension: nil,
                            itemType: .folder
                        )

                        completionHandler(folderItem, nil)
                        self.logger.info("✅ Got metadata for folder with name \(folderItem.filename)")
                        return
                    }
                }
                throw GetFileOrFolderMetaUseCaseError.FileOrFolderMetaNotFound
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Failed to get item meta for \(identifier.rawValue): \(error.getErrorDescription())")
                completionHandler(nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
    
    private func getFileMetaOrNil(maybeFileUuid: String) async -> GetFileMetaByIdResponse? {
        do {
            let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: maybeFileUuid)
            
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
            return try await driveNewAPI.getFolderMetaById(id: maybeFolderId)
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
