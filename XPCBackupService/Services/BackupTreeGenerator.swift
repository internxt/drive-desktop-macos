//
//  BackupTreeGenerator.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation
import os.log

enum BackupTreeGeneratorError: Error {
    case parentNodeNotFound
    case rootIsNotDirectory
    case enumeratorNotFound
}

protocol BackupTreeGeneration {
    var root: URL {get set}
    var rootNode: BackupTreeNode { get }
    func generateTree() async throws -> BackupTreeNode
    
}
class BackupTreeGenerator: BackupTreeGeneration {
    let logger = Logger(subsystem: "com.internxt", category: "BackupTreeGenerator")
    var root: URL
    let rootNode: BackupTreeNode
    
    init(root: URL) {
        
        self.root = root
        rootNode = BackupTreeNode(
            id: UUID().uuidString,
            parentId: nil,
            name: "BACKUP_ROOT",
            type: BackupTreeNodeType.folder,
            url: self.root,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: []
        )
    }
    
    
    /**
     * Generates a tree from a list of URLs of the system
     **/
    func generateTree() async throws -> BackupTreeNode {
        
        return try await withUnsafeThrowingContinuation{ continuation in
            if self.root.isDirectory {
                guard let enumerator = FileManager.default.enumerator(
                    at: self.root,
                    includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
                    options: []
                ) else {
                    continuation.resume(throwing: BackupTreeGeneratorError.enumeratorNotFound)
                    return
                }
                
                for case let url as URL in enumerator {
                    do {
                        try self.insertInTree(url)
                    } catch{
                        // We need to decide what to do in this case, for now, at least log the error
                        logger.error("Failed to insert URL \(url) in the backup tree: \(error)")
                    }
                }
                
                continuation.resume(returning: self.rootNode)
                
                
            } else {
                continuation.resume(throwing: BackupTreeGeneratorError.rootIsNotDirectory)
            }
        }
        
    }
    
    func insertInTree(_ url: URL) throws {
        
        // 1. Find a parent for the node
        guard let parentNode = self.rootNode.findNode(url.deletingLastPathComponent()) else {
            throw BackupTreeGeneratorError.parentNodeNotFound
        }
        
        // 2. Check if the node already exists in the parent instead of the whole tree, so
        // we don't traverse the entire tree again
        let existingNode = parentNode.findNode(url)
        
        if(existingNode != nil) {
            return
        }
        
        
        // 3. We have a parent, and the node does not exists, create the BackupTreeNode
        let newNode = BackupTreeNode(
            id: UUID().uuidString,
            parentId: parentNode.id,
            name: url.deletingPathExtension().lastPathComponent,
            type: BackupTreeNodeType.folder,
            url: url,
            syncStatus: BackupTreeNodeSyncStatus.LOCAL_ONLY,
            childs: []
        )
        
        
        parentNode.addChild(newNode: newNode)
    }
}
