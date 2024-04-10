//
//  BackupTreeNode.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation

enum BackupTreeNodeError: Error {
    case cannotGetPath
}

class BackupTreeNode {
    var id: String
    var parentId: String?
    var name: String
    var type: BackupTreeNodeType
    var url: URL?
    private(set) var syncStatus: BackupTreeNodeSyncStatus
    var remoteId: Int?
    var remoteUuid: String?
    var remoteParentId: Int?
    private(set) var childs: [BackupTreeNode]
    let backupUploadService: BackupUploadService
    var backupTotalPogress: Progress
    var rootBackupFolder: URL

    init(id: String, rootBackupFolder: URL, parentId: String?, name: String, type: BackupTreeNodeType, url: URL?, syncStatus: BackupTreeNodeSyncStatus, childs: [BackupTreeNode], backupUploadService: BackupUploadService, backupTotalProgress: Progress) {
        self.id = id
        self.parentId = parentId
        self.rootBackupFolder = rootBackupFolder
        self.name = name
        self.type = type
        self.url = url
        self.syncStatus = syncStatus
        self.childs = childs
        self.backupUploadService = backupUploadService
        self.backupTotalPogress = backupTotalProgress
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

    private func getFileModificationDate() throws -> Date? {
        guard let path = self.url?.path else {
            throw BackupTreeNodeError.cannotGetPath
        }

        let attribute = try FileManager.default.attributesOfItem(atPath: path)
        return attribute[FileAttributeKey.modificationDate] as? Date
    }

    private func nodeIsSynced(url: String) throws -> Bool {
        let realm = try BackupRealm.shared.getRealm()
        let syncedNode = realm.objects(SyncedNode.self).first { syncedNode in
            url == syncedNode.url
        }

        guard let syncedNodeDate = syncedNode?.updatedAt, let fileModificationDate = try self.getFileModificationDate() else {
            return false
        }

        if (syncedNodeDate < fileModificationDate && self.type != .folder) {
            self.syncStatus = .NEEDS_UPDATE
            self.remoteId = syncedNode?.remoteId
            self.remoteUuid = syncedNode?.remoteUuid
            return false
        }

        return syncedNode != nil
    }
    
    func syncNodes() async throws -> Void {
        // sync current node
        try await self.syncNode()

        for child in self.childs {
            // sync each child nodes
            try await child.syncNodes()
        }
    }
    
    private func syncNode() async throws -> Void {
        
        guard let filePath = self.url?.absoluteString else {
            throw BackupTreeNodeError.cannotGetPath
        }
        let isSynced = try self.nodeIsSynced(url: filePath)
        
        if !isSynced {
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
                backupTotalPogress.completedUnitCount += 1
                error.reportToSentry()
                return
            }

        } else {
            backupTotalPogress.completedUnitCount += 1
            let realm = try BackupRealm.shared.getRealm()
            let syncedNode = realm.objects(SyncedNode.self).first { syncedNode in
                self.url?.absoluteString == syncedNode.url
            }
            self.syncStatus = .REMOTE_AND_LOCAL
            self.remoteId = syncedNode?.remoteId
            self.remoteUuid = syncedNode?.remoteUuid
            for child in self.childs {
                child.remoteParentId = syncedNode?.remoteId
            }
        }
    }

}




