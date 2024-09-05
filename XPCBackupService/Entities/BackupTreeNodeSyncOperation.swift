//
//  BackupTreeNodeSyncOperation.swift
//  XPCBackupService
//
//  Created by Robert Garcia on 27/5/24.
//

import Foundation

class BackupTreeNodeSyncOperation: AsyncOperation {
    private let backupTreeNode: BackupTreeNode
    var onError: ((Error) -> Void)?

      init(backupTreeNode: BackupTreeNode) {
          self.backupTreeNode = backupTreeNode
      }
    
    override func performAsyncTask() async throws -> Void {
        do {
            try await self.backupTreeNode.syncNode()
        } catch {
            onError?(error)
            throw error
        }
    }
}
