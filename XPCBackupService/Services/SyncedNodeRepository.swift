//
//  BackupRealm.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 3/8/24.
//

import Foundation
import RealmSwift


protocol SyncedNodeRepositoryProtocol: GenericRepositoryProtocol {
    
    func addSyncedNode(_ node: SyncedNode) throws
    func findSyncedNode(url: URL, deviceId: Int) -> SyncedNode?
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws
    func resolveSyncedNode(reference: ThreadSafeReference<SyncedNode>) -> SyncedNode?
}

struct SyncedNodeRepository : SyncedNodeRepositoryProtocol {
    
    
    typealias T = SyncedNode
    static var shared = SyncedNodeRepository()
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
            let detachedNode = SyncedNode(value: node)
            try realm?.write {
                realm?.add(detachedNode)
            }
        } catch {
            throw BackupUploadError.CannotAddNodeToRealm
        }
    }
    
    
    func findSyncedNode(url: URL, deviceId: Int) -> SyncedNode? {
        do {
            let realm = try Realm()
            return realm.objects(SyncedNode.self)
                .filter("url == %@ AND deviceId == %@", url.absoluteString, deviceId)
                .first
        } catch {
            logger.error("Failed to open Realm: \(error)")
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
    
    func findById(id: String) -> SyncedNode? {
        return nil
    }
    
    func deleteById(id: String) throws {
        // TODO:
    }
    
    func updateById(id: String) throws {
        // TODO:
    }
    
    func resolveSyncedNode(reference: ThreadSafeReference<SyncedNode>) -> SyncedNode? {
        do {
            let realm = try Realm()
            return realm.resolve(reference)
        } catch {
            logger.error("Failed to resolve thread-safe reference: \(error)")
            return nil
        }
    }
    
}
