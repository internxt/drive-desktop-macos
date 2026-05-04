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
            
            guard !self.isCancelled else { return }
            
            // Children are enqueued dynamically ONLY AFTER the parent successfully syncs.
            // This temporal causality guarantees that child nodes will always have the
            // required remoteParentId populated before they execute, preserving the
            // strict parent-child order without needing explicit KVO dependencies.
            for child in self.backupTreeNode.childs {
                try child.syncBelowNodes(withOperationQueue: self.operationQueue, syncGroup: self.syncGroup, onError: self.onError ?? { _ in })
            }
        } catch {
            // Error handling policy:
            // 1. If syncNode() fails, we catch the error here and do NOT enqueue children.
            //    (Files in a failed folder cannot be synced anyway).
            // 2. Fatal errors (e.g. storageFull) will trigger cancelAllOperations() at the XPC layer.
            // 3. Non-fatal errors are counted as failures, but sibling branches will continue processing.
            onError?(error)
            throw error
        }
    }
}
