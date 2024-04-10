//
//  SyncedNode.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 3/19/24.
//

import Foundation
import RealmSwift

class SyncedNode: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var remoteId: Int
    @Persisted var remoteUuid: String
    @Persisted(indexed: true) var url: String
    @Persisted(indexed: true) var rootBackupFolder: String
    @Persisted var parentId: String?
    @Persisted var remoteParentId: Int?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date

    convenience init(
        remoteId: Int,
        remoteUuid: String,
        url: URL,
        rootBackupFolder: URL,
        parentId: String?,
        remoteParentId: Int?
    ) {
        self.init()
        self.remoteId = remoteId
        self.remoteUuid = remoteUuid
        self.url = url.absoluteString
        self.rootBackupFolder = url.absoluteString
        self.parentId = parentId
        self.remoteParentId = remoteParentId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
