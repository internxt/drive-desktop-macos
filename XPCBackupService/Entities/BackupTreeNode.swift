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
        // This should sync the current node, and all the child nodes recursively
    }
    
    func syncNode() async throws -> Void {
        // This should sync the current node with Internxt API (upload or create a folder, based on self.type)
        // Once synced, update the syncStatus
    }
}




