//
//  BackupTreeGenerator.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation
import UniformTypeIdentifiers

enum BackupTreeGeneratorError: Error {
    case parentNodeNotFound
    case rootIsNotDirectory
    case enumeratorNotFound
    case cannotGetNodeType
    case missingRootRemoteId
}

protocol BackupTreeGeneration {
    var root: URL {get set}
    var rootNode: BackupTreeNode { get }
    func generateTree() async throws -> BackupTreeNode
    
}
class BackupTreeGenerator: BackupTreeGeneration {
    private let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "App")
    var root: URL
    let rootNode: BackupTreeNode
    let backupUploadService: BackupUploadServiceProtocol
    let backupTotalProgress: Progress
    let deviceId: Int
    let backupRealm: any SyncedNodeRepositoryProtocol
    
    private var nodeIndex: [URL: BackupTreeNode] = [:]
   
    init(root: URL, deviceId: Int, backupUploadService: BackupUploadServiceProtocol, backupTotalProgress: Progress, backupRealm: any SyncedNodeRepositoryProtocol) {

        self.root = root
        self.backupUploadService = backupUploadService
        self.backupTotalProgress = backupTotalProgress
        self.deviceId = deviceId
        self.backupRealm = backupRealm
        rootNode = BackupTreeNode(
            id: UUID().uuidString,
            deviceId: deviceId,
            rootBackupFolder: root,
            parentId: nil,
            name: root.lastPathComponent,
            type: BackupTreeNodeType.folder,
            url: self.root,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: [],
            backupUploadService: self.backupUploadService,
            backupRealm: self.backupRealm,
            backupTotalProgress: self.backupTotalProgress
        )
        
        nodeIndex[root] = rootNode
    }
    
    
    /**
     * Generates a tree from a list of URLs of the system
     **/
    func generateTree() async throws -> BackupTreeNode {

        return try await withUnsafeThrowingContinuation { continuation in
            do {
                if try self.root.isDirectory() {
                    guard let enumerator = FileManager.default.enumerator(
                        at: self.root,
                        includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    ) else {
                        logger.error("Enumerator not found")
                        continuation.resume(throwing: BackupTreeGeneratorError.enumeratorNotFound)
                        return
                    }

                    for case let url as URL in enumerator {
                        do {
                            try self.insertInTree(url)
                        } catch {
                            // We need to decide what to do in this case, for now, at least log the error
                            logger.error("Failed to insert URL \(url) in the backup tree: \(error)")
                        }
                    }

                    continuation.resume(returning: self.rootNode)

                } else {
                    logger.error("Node \(self.root) is not a directory")
                    continuation.resume(throwing: BackupTreeGeneratorError.rootIsNotDirectory)
                }
            } catch {
                logger.error(["Cannot check if node \(self.root) is directory", error])
                error.reportToSentry()
                continuation.resume(throwing: BackupTreeGeneratorError.rootIsNotDirectory)
            }
        }

    }
    
    
    func insertInTree(_ url: URL) throws {
         //  Check if the node already exists in the parent instead of the whole tree
         if nodeIndex[url] != nil {
             return
         }

         // 1. Find a parent for the node
         let parentURL = url.deletingLastPathComponent()
         guard let parentNode = nodeIndex[parentURL] else {
             throw BackupTreeGeneratorError.parentNodeNotFound
         }

         guard let typeID = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier,
               let type = UTType(typeID) else {
             throw BackupTreeGeneratorError.cannotGetNodeType
         }

         // We have a parent, and the node does not exists, create the BackupTreeNode
         let newNode = BackupTreeNode(
             id: UUID().uuidString,
             deviceId: self.deviceId,
             rootBackupFolder: root,
             parentId: parentNode.id,
             name: url.lastPathComponent,
             type: type,
             url: url,
             syncStatus: .LOCAL_ONLY,
             childs: [],
             backupUploadService: self.backupUploadService,
             backupRealm: self.backupRealm,
             backupTotalProgress: self.backupTotalProgress
         )

   
         parentNode.addChild(newNode: newNode)
         nodeIndex[url] = newNode
     }
 }
