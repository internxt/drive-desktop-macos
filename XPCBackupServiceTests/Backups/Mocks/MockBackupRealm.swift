//
//  MockBackupRealm.swift
//  InternxtDesktopTests
//
//  Created by Patricio Tovar on 18/6/24.
//

import Foundation
import RealmSwift

class MockBackupRealm: BackupRealmProtocol {
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
    
    func findSyncedNode(url: URL, deviceId: Int) -> ThreadSafeReference<SyncedNode>? {
        do{
            let realm = try getRealm()
            let syncedNode = realm?.objects(SyncedNode.self).first { syncedNode in
                url.absoluteString == syncedNode.url && deviceId == syncedNode.deviceId
            }
            if let syncedNode = syncedNode {
                return ThreadSafeReference(to: syncedNode)
            }
            return nil
        }
        catch {
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
}
