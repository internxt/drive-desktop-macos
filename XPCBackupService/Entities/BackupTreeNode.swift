//
//  BackupTreeNode.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation
import RealmSwift

enum BackupTreeNodeError: Error {
    case cannotGetPath
}

let MAX_SYNC_RETRIES = 3

class BackupTreeNode {
    var id: String
    var parentId: String?
    var deviceId: Int
    var name: String
    var type: BackupTreeNodeType
    var url: URL?
    private(set) var syncStatus: BackupTreeNodeSyncStatus
    var remoteId: Int?
    var remoteUuid: String?
    var remoteParentId: Int?
    private(set) var childs: [BackupTreeNode]
    let backupUploadService: BackupUploadServiceProtocol
    var backupTotalPogress: Progress
    var rootBackupFolder: URL
    var syncRetries: UInt64 = 0
    var backupRealm: SyncedNodeRepository
    
    init(id: String, deviceId: Int, rootBackupFolder: URL, parentId: String?, name: String, type: BackupTreeNodeType, url: URL?, syncStatus: BackupTreeNodeSyncStatus, childs: [BackupTreeNode], backupUploadService: BackupUploadServiceProtocol, backupRealm: SyncedNodeRepository, backupTotalProgress: Progress) {
        self.id = id
        self.deviceId = deviceId
        self.parentId = parentId
        self.rootBackupFolder = rootBackupFolder
        self.name = name
        self.type = type
        self.url = url
        self.syncStatus = syncStatus
        self.childs = childs
        self.backupUploadService = backupUploadService
        self.backupTotalPogress = backupTotalProgress
        self.backupRealm = backupRealm
    }
    
    func addChild(newNode: BackupTreeNode){
        childs.append(newNode)
    }
    
    func findNodeById(_ id: String) -> BackupTreeNode? {
        if self.id == id {
            return self
        }

        for child in self.childs {
            if let match = child.findNodeById(id) {
                return match
            }
        }

        return nil
    }
    
    func findNode(_ url: URL) -> BackupTreeNode? {
        if self.url == url {
            return self
        }

        for child in self.childs {
            if let match = child.findNode(url) {
                return match
            }
        }

        return nil
    }
    
    func removeChildNodes() -> Void {
        self.childs.forEach{childNode in
            childNode.removeChildNodes()
        }
        self.childs = []
    }

    private func getFileModificationDate() throws -> Date? {
        guard let path = self.url?.path else {
            throw BackupTreeNodeError.cannotGetPath
        }

        let attribute = try FileManager.default.attributesOfItem(atPath: path)
        return attribute[FileAttributeKey.modificationDate] as? Date
    }

    private func nodeIsSynced(url: URL, deviceId: Int) throws -> SyncedNode? {
        let syncedNodeThreadRef = autoreleasepool {
            let syncedNodeThreadRef = backupRealm.findSyncedNode(url: url, deviceId: deviceId)
            
            return syncedNodeThreadRef
        }
        
        guard let syncedNodeThreadRefUnwrapped = syncedNodeThreadRef else {
            return nil
        }
        guard let realm = try backupRealm.getRealm() else {
            return nil
        }
        
        let syncedNode = realm.resolve(syncedNodeThreadRefUnwrapped)
        
        guard let syncedNodeUnwrapped = syncedNode else {
            return nil
        }
        
    
        let syncedNodeDate = syncedNodeUnwrapped.updatedAt
        
        guard let fileModificationDate = try self.getFileModificationDate() else {
            return nil
        }

        if (syncedNodeDate < fileModificationDate && self.type != .folder) {
            self.syncStatus = .NEEDS_UPDATE
            self.remoteId = syncedNode?.remoteId
            self.remoteUuid = syncedNode?.remoteUuid
            
            return nil
        }
        

        return syncedNodeUnwrapped
    }
    
    func syncBelowNodes(withOperationQueue: OperationQueue, dependingOfOperation: BackupTreeNodeSyncOperation? = nil) throws -> Void {

        let operation = BackupTreeNodeSyncOperation(backupTreeNode: self)
        // If the node is already synced, we just update it, otherwise, move it
        // to the queue, so it gets synced later
        if(dependingOfOperation != nil) {
            operation.addDependency(dependingOfOperation!)
        }
        withOperationQueue.addOperation(operation)
    
        
        
       
        for child in self.childs {
            if(self.type == .folder) {
                // If current node is a folder, make below sync operations dependent of the folder sync operation
                try child.syncBelowNodes(withOperationQueue: withOperationQueue, dependingOfOperation: operation)
            } else {
                // If current node is not a folder, below sync operations does not depend on parent node sync operation
                try child.syncBelowNodes(withOperationQueue: withOperationQueue)
            }
            
        }
    }
    
   
 
    func syncNode() async throws -> Void {
        
        guard let nodeURL = self.url else {
            throw BackupTreeNodeError.cannotGetPath
        }
        
        let currentSyncedNode = try self.nodeIsSynced(url: nodeURL, deviceId: self.deviceId)
        if let threadRealm = try self.backupRealm.getRealm(), let currentSyncedNodeUnwrapped = currentSyncedNode {
            try self.updateNodeAsAlreadySynced(syncedNodeRemoteId: currentSyncedNodeUnwrapped.remoteId, syncedNoteRemoteUuid: currentSyncedNodeUnwrapped.remoteUuid)
            
            logger.info("Node \(self.name) is synced: \(currentSyncedNode != nil)")
            
            return
        }
        
        

        
        
        let syncResult = await backupUploadService.doSync(node: self)
        
        switch syncResult {
            case .success(let backupTreeNodeSyncResult):
                backupTotalPogress.completedUnitCount += 1
                let remoteId = backupTreeNodeSyncResult.id
                let remoteUuid = backupTreeNodeSyncResult.uuid
                self.syncStatus = .REMOTE_AND_LOCAL
                self.remoteId = remoteId
                self.remoteUuid = remoteUuid
                for child in self.childs {
                    child.remoteParentId = remoteId
                }
            case .failure(let error):
                if case BackupUploadError.BackupStoppedManually = error {
                    // Noop, this was stopped
                } else {
                    
                    if syncRetries >= MAX_SYNC_RETRIES {
                        logger.info("Node sync failed, no more retries allowed")
                    } else {
                        syncRetries += 1
                        logger.info("Node sync failed, scheduling retry #\(syncRetries)")
                        error.reportToSentry()
                        try await Task.sleep(nanoseconds: 1_000_000_000 * syncRetries)
                        try await self.syncNode()
                    }
                }
                
                return
            }
    }

    
    func updateNodeAsAlreadySynced(syncedNodeRemoteId: Int, syncedNoteRemoteUuid: String) throws {
        backupTotalPogress.completedUnitCount += 1
        
        self.syncStatus = .REMOTE_AND_LOCAL
        self.remoteId = syncedNodeRemoteId
        self.remoteUuid = syncedNoteRemoteUuid
        for child in self.childs {
            child.remoteParentId = remoteId
        }
    }
}




