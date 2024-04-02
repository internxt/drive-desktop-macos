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
            return try Realm(configuration: Realm.Configuration(
                fileURL: ConfigLoader.realmURL,
                deleteRealmIfMigrationNeeded: true
            ))
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
