//
//  BackupTreeNode.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation

class BackupTreeNode {
    var id: String
    var parentId: String?
    var name: String
    var type: BackupTreeNodeType
    var url: URL?
    private(set) var syncStatus: BackupTreeNodeSyncStatus
    var remoteId: String?
    var remoteParentId: String?
    private(set) var childs: [BackupTreeNode]

    init(id: String, parentId: String?, name: String, type: BackupTreeNodeType, url: URL?, syncStatus: BackupTreeNodeSyncStatus, childs: [BackupTreeNode]) {
        self.id = id
        self.parentId = parentId
        self.name = name
        self.type = type
        self.url = url
        self.syncStatus = syncStatus
        self.childs = childs
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
    
    func nodeIsSynced() async throws -> Bool {
        // This should check if the node is already synced or not, by checking against
        // the backend, or a local database to avoid network hits
        return false
    }
    
    func syncNodes() async throws -> Void {
        do {
            // sync current node
            try await self.syncNode()

            for child in self.childs {
                // sync each child nodes
                try await syncNodes()
            }
        } catch {
            print("error", error.localizedDescription)
        }
    }
    
    func syncNode() async throws -> Void {
        // This should sync the current node with Internxt API (upload or create a folder, based on self.type)
        // Once synced, update the syncStatus
    }
}




