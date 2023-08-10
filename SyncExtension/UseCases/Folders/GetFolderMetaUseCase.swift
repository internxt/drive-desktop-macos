//
//  GetFolderMetaUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 9/8/23.
//

import Foundation

import FileProvider
import InternxtSwiftCore
import os.log

enum GetFolderMetaUseCaseError: Error {
    case InvalidItemId
    case TrashRequestFailed
    case InvalidCreatedAt
    case InvalidUpdatedAt
}


struct GetFolderMetaUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "GetFolderMeta")
    private let driveAPI: DriveAPI = APIFactory.Drive
    private let completionHandler: (NSFileProviderItem?, Error?) -> Void
    private let identifier: NSFileProviderItemIdentifier
    init(identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (NSFileProviderItem?, Error?) -> Void) {
        self.completionHandler = completionHandler
        self.identifier = identifier
    }
    
    public func run( ) -> Progress {
        self.logger.info("Getting metadata for folder \(self.identifier.rawValue)")
        Task {
            do {
                let folderMeta = try await driveAPI.getFolderMetaById(id: self.identifier.rawValue)
                
                var parentId: NSFileProviderItemIdentifier = .rootContainer
                
                if folderMeta.parentId != nil && String(folderMeta.parentId!) != nil {
                    parentId = NSFileProviderItemIdentifier(String(folderMeta.parentId!))
                }
                
                guard let createdAt = Time.dateFromISOString(folderMeta.createdAt) else {
                    throw GetFolderMetaUseCaseError.InvalidCreatedAt
                }
                
                guard let updateAt = Time.dateFromISOString(folderMeta.updatedAt) else {
                    throw GetFolderMetaUseCaseError.InvalidUpdatedAt
                }
                
                let folderItem = FileProviderItem(
                    identifier: self.identifier,
                    filename: folderMeta.name,
                    parentId: parentId ,
                    createdAt: createdAt,
                    updatedAt: updateAt,
                    itemExtension: nil,
                    itemType: .folder
                )
                
                completionHandler(folderItem, nil)
            } catch {
                self.logger.error("Failed to get folder meta for \(identifier.rawValue): \(error.localizedDescription)")
                completionHandler(nil, NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        
        return Progress()
    }
}
