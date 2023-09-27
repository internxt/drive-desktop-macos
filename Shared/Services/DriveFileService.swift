//
//  DriveFileService.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 26/9/23.
//

import Foundation
import InternxtSwiftCore


enum DriveFileError: Error {
    case TrashNotSuccess
}

struct DriveFileService {
    static var shared = DriveFileService()
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let driveAPI: DriveAPI = APIFactory.Drive
    
    
    /// Given a file uuid, modifies it status to **TRASHED**
    ///
    /// - Parameter uuid: The file uuid
    /// - Throws: An error of type `DriveFileError`
    /// - Returns: A `DriveFile` with the updated status to `DriveItemStatus.trashed`
    /// 
    public func trashFile(uuid: String) async throws -> DriveFile {
        let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: uuid)
      
        
        let trashed: Bool = try await trashAPI.trashFiles(itemsToTrash: [FileToTrash(
            id: fileMeta.fileId
        )])
        
        if trashed == false {
            throw DriveFileError.TrashNotSuccess
        }
        
        let createdAt = Time.dateFromISOString(fileMeta.createdAt) ?? Date()
        let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) ?? Date()
        
        
        return DriveFile(
            uuid: fileMeta.uuid,
            plainName: fileMeta.plainName,
            name: fileMeta.name,
            type: fileMeta.type,
            size: Int(fileMeta.size) ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt,
            folderId: fileMeta.folderId,
            status: .trashed
        )
    }
    
    
    /// Given a file uuid, modifies it name to a new name
    ///
    /// - Parameter uuid: The file uuid to rename
    /// - Parameter bucketId: The bucket id where the file is stored
    /// - Parameter newName: The new name of the file, without extension
    /// - Throws: An error of type `DriveFileError`
    /// - Returns: A `DriveFile` with the updated name
    ///
    public func renameFile(uuid: String, bucketId: String, newName: String) async throws -> DriveFile {
        let fileMeta = try await driveNewAPI.getFileMetaByUuid(uuid: uuid)
        
        let updated = try await driveAPI.updateFile(
            fileId: fileMeta.fileId,
            bucketId: bucketId,
            newFilename: newName,
            debug: false
        )
        
        let createdAt = Time.dateFromISOString(fileMeta.createdAt) ?? Date()
        let updatedAt = Time.dateFromISOString(fileMeta.updatedAt) ?? Date()
        
        return DriveFile(
            uuid: fileMeta.uuid,
            plainName: updated.plain_name,
            name: fileMeta.name,
            type: fileMeta.type,
            size: Int(fileMeta.size) ?? 0,
            createdAt: createdAt,
            updatedAt: updatedAt,
            folderId: fileMeta.folderId,
            status: DriveItemStatus(rawValue: fileMeta.status) ?? .exists
        )
    }
}
