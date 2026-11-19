//
//  BackupTreeNodeSyncResult.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 3/8/24.
//

import Foundation

struct BackupTreeNodeSyncResult {
    let id: Int?
    let uuid: String?

    init(id: Int? = nil, uuid: String?) {
        self.id = id
        self.uuid = uuid
    }
}
