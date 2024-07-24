//
//  BackupRealm.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 3/8/24.
//

import Foundation
import RealmSwift

protocol BackupRealmProtocol {
    func getRealm() throws -> Realm?
    func addSyncedNode(_ node: SyncedNode) throws
    func findSyncedNode(url: URL, deviceId: Int) -> ThreadSafeReference<SyncedNode>?
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws
}

struct BackupRealm : GenericRepositoryProtocol {
    typealias T = SyncedNode
    static var shared = BackupRealm()
    private var realm: Realm?
    private init() {}

    func getRealm() throws -> Realm? {
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
            try realm?.write {
                realm?.add(node)
            }
        } catch {
            throw BackupUploadError.CannotAddNodeToRealm
        }
    }
    
    func findSyncedNode(url: URL, deviceId: Int) -> ThreadSafeReference<SyncedNode>? {
        do {
            let realm = try getRealm()

            let syncedNode = realm?.objects(SyncedNode.self).first { syncedNode in
                url.absoluteString == syncedNode.url && deviceId == syncedNode.deviceId
            }
            guard let syncedNodeUnwrapped = syncedNode else {
                return nil
            }
            return ThreadSafeReference(to: syncedNodeUnwrapped)
        } catch {
            return nil
        }
    }

    func editSyncedNodeDate(remoteUuid: String, date: Date) throws {
        do {
            let realm = try getRealm()

            guard let node = realm?.objects(SyncedNode.self).first(where: { syncedNode in
                syncedNode.remoteUuid == remoteUuid
            }) else {
                throw BackupUploadError.CannotFindNodeToRealm
            }

            try realm?.write {
                node.updatedAt = date
            }
        } catch {
            throw BackupUploadError.CannotEditNodeToRealm
        }
    }
    
    func find(url: URL, deviceId: Int) -> SyncedNode? {
        do {
            let realm = try getRealm()
            return realm?.objects(SyncedNode.self).first { $0.url == url.absoluteString && $0.deviceId == deviceId }
        } catch {
            return nil
        }
    }

}
