//
//  MockBackupUploadService.swift
//  InternxtDesktopTests
//
//  Created by Patricio Tovar on 18/6/24.
//

import Foundation

class MockBackupUploadService: BackupUploadServiceProtocol {
    var syncResult: Result<BackupTreeNodeSyncResult, Error>?
    
    func doSync(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error> {
        if let result = syncResult {
            return result
        }
        if node.type == .folder {
            return .success(BackupTreeNodeSyncResult(id: 100, uuid: nil))
        }
        return .success(BackupTreeNodeSyncResult(id: 100, uuid: "ABC123456"))
        
    }
    
    func stopSync() {
       // TODO:
    }
}
