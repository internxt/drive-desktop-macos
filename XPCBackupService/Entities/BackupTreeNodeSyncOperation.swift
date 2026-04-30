//
//  BackupTreeNodeSyncOperation.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 27/5/24.
//

import Foundation

class BackupTreeNodeSyncOperation: AsyncOperation {
    private let backupTreeNode: BackupTreeNode
    private let operationQueue: OperationQueue
    private let syncGroup: DispatchGroup
    var onError: ((Error) -> Void)?

    init(backupTreeNode: BackupTreeNode, operationQueue: OperationQueue, syncGroup: DispatchGroup) {
        self.backupTreeNode = backupTreeNode
        self.operationQueue = operationQueue
        self.syncGroup = syncGroup
    }
    
    override func performAsyncTask() async throws -> Void {
        do {
            try await self.backupTreeNode.syncNode()
            
            for child in self.backupTreeNode.childs {
                try child.syncBelowNodes(withOperationQueue: self.operationQueue, syncGroup: self.syncGroup, onError: self.onError ?? { _ in })
            }
        } catch {
            onError?(error)
            throw error
        }
    }
}
