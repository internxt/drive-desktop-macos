//
//  MockBackupRealm.swift
//  InternxtDesktopTests
//
//  Created by Patricio Tovar on 18/6/24.
//

import Foundation
import RealmSwift

class MockBackupRealm: SyncedNodeRepositoryProtocol {

    func find(url: URL, deviceId: Int) -> SyncedNode? {
        // TODO:
        return nil
    }
    
    private let inMemoryRealm: Realm
    
    init() {
        var configuration = Realm.Configuration()
        configuration.inMemoryIdentifier = "MockBackupRealm"
        inMemoryRealm = try! Realm(configuration: configuration)
    }
    
    func getRealm() throws -> Realm? {
        var configuration = Realm.Configuration()
        configuration.inMemoryIdentifier = "MockBackupRealm"
        return try! Realm(configuration: configuration)
    }
    
    func addSyncedNode(_ node: SyncedNode) throws {
        let realm = try getRealm()
        try realm?.write {
            realm?.add(node)
        }
    }
    
    func addSyncedNodeAsync(_ node: SyncedNode) async throws {
        try addSyncedNode(node)
    }
    
    func findSyncedNode(url: URL, deviceId: Int) -> SyncedNode? {
        do {
            let realm = try getRealm()
            return realm?.objects(SyncedNode.self).first { syncedNode in
                url.absoluteString == syncedNode.url && deviceId == syncedNode.deviceId
            }
        } catch {
            return nil
        }
    }
    
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws {
        guard let node = inMemoryRealm.objects(SyncedNode.self).first(where: { $0.remoteUuid == remoteUuid }) else {
            throw BackupUploadError.CannotFindNodeToRealm
        }
        try inMemoryRealm.write {
            node.updatedAt = date
        }
    }
    
    func editSyncedNodeDateAsync(remoteUuid: String, date: Date) async throws {
        try editSyncedNodeDate(remoteUuid: remoteUuid, date: date)
    }
    
    func deleteSyncedNodeByRemoteIdAsync(remoteId: Int) async throws {
        let nodes = inMemoryRealm.objects(SyncedNode.self).filter("remoteId == %@", remoteId)
        try inMemoryRealm.write {
            inMemoryRealm.delete(nodes)
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
            let realm = try getRealm()
            guard let realm = realm else { return nil }
            return realm.resolve(reference)
        } catch {
            return nil
        }
    }
}
