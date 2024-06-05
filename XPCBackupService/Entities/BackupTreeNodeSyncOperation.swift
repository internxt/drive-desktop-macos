//
//  BackupTreeNodeSyncOperation.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 27/5/24.
//

import Foundation

class BackupTreeNodeSyncOperation: AsyncOperation {
    private let backupTreeNode: BackupTreeNode
    
    init(backupTreeNode: BackupTreeNode) {
        self.backupTreeNode = backupTreeNode
    }
    
    override func performAsyncTask() async throws -> Void {
       try await self.backupTreeNode.syncNode()
    }
}
