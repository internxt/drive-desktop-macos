//
//  BackupRealm.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 3/8/24.
//

import Foundation
import RealmSwift

struct BackupRealm {
    static let shared = BackupRealm()

    private init() {}

    func getRealm() throws -> Realm {
        do {
            let config = Realm.Configuration(schemaVersion: 2)
            Realm.Configuration.defaultConfiguration = config
            return try Realm(fileURL: ConfigLoader.realmURL)
        } catch {
            throw BackupUploadError.CannotCreateRealm
        }
    }

    func addSyncedNode(_ node: SyncedNode) throws {
        do {
            let realm = try getRealm()
            try realm.write {
                realm.add(node)
            }
        } catch {
            throw BackupUploadError.CannotAddNodeToRealm
        }
    }

    func editSyncedNodeDate(remoteUuid: String, date: Date) throws {
        do {
            let realm = try getRealm()

            guard let node = realm.objects(SyncedNode.self).first(where: { syncedNode in
                syncedNode.remoteUuid == remoteUuid
            }) else {
                throw BackupUploadError.CannotFindNodeToRealm
            }

            try realm.write {
                node.updatedAt = date
            }
        } catch {
            throw BackupUploadError.CannotEditNodeToRealm
        }
    }

}

class SyncedNode: Object {
    @Persisted(primaryKey: true) var _id: ObjectId
    @Persisted var remoteId: Int
    @Persisted var remoteUuid: String
    @Persisted(indexed: true) var url: String
    @Persisted var parentId: String?
    @Persisted var remoteParentId: Int?
    @Persisted var createdAt: Date
    @Persisted var updatedAt: Date

    convenience init(
        remoteId: Int,
        remoteUuid: String,
        url: String,
        parentId: String?,
        remoteParentId: Int?
    ) {
        self.init()
        self.remoteId = remoteId
        self.remoteUuid = remoteUuid
        self.url = url
        self.parentId = parentId
        self.remoteParentId = remoteParentId
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
