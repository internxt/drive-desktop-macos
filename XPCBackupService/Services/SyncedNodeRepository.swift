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
    func addSyncedNodeAsync(_ node: SyncedNode) async throws
    func findSyncedNode(url: URL, deviceId: Int) -> SyncedNode?
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws
    func editSyncedNodeDateAsync(remoteUuid: String, date: Date) async throws
    func resolveSyncedNode(reference: ThreadSafeReference<SyncedNode>) -> SyncedNode?
}


final class SyncedNodeRepository : SyncedNodeRepositoryProtocol {
    
    typealias T = SyncedNode
    static let shared = SyncedNodeRepository()
    
    /// Dedicated serial queue for all Realm operations
    private let realmQueue = DispatchQueue(label: "com.internxt.backup.realmQueue", qos: .userInitiated)
    
    private init() {}
    
    private func getRealm() throws -> Realm {
        dispatchPrecondition(condition: .onQueue(realmQueue))
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
        var thrownError: Error?
        realmQueue.sync {
            do {
                let realm = try getRealm()
                let detachedNode = SyncedNode(value: node)
                try realm.write {
                    realm.add(detachedNode)
                }
            } catch {
                thrownError = BackupUploadError.CannotAddNodeToRealm
            }
        }
        if let error = thrownError {
            throw error
        }
    }
    
    func findSyncedNode(url: URL, deviceId: Int) -> SyncedNode? {
        return realmQueue.sync {
            do {
                let realm = try getRealm()
                if let node = realm.objects(SyncedNode.self)
                    .filter("url == %@ AND deviceId == %@", url.absoluteString, deviceId)
                    .first {
                   
                    return SyncedNode(value: node)
                }
                return nil
            } catch {
                logger.error("Failed to open Realm: \(error)")
                return nil
            }
        }
    }
    
    func editSyncedNodeDate(remoteUuid: String, date: Date) throws {
        var thrownError: Error?
        realmQueue.sync {
            do {
                let realm = try getRealm()
                
                guard let node = realm.objects(SyncedNode.self).first(where: { syncedNode in
                    syncedNode.remoteUuid == remoteUuid
                }) else {
                    thrownError = BackupUploadError.CannotFindNodeToRealm
                    return
                }
                
                try realm.write {
                    node.updatedAt = date
                }
            } catch {
                thrownError = BackupUploadError.CannotEditNodeToRealm
            }
        }
        if let error = thrownError {
            throw error
        }
    }
    
    func find(url: URL, deviceId: Int) -> SyncedNode? {
        return realmQueue.sync {
            do {
                let realm = try getRealm()
                if let node = realm.objects(SyncedNode.self).first(where: { $0.url == url.absoluteString && $0.deviceId == deviceId }) {
                    
                    return SyncedNode(value: node)
                }
                return nil
            } catch {
                return nil
            }
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
        return realmQueue.sync {
            do {
                let realm = try getRealm()
                if let node = realm.resolve(reference) {
                
                    return SyncedNode(value: node)
                }
                return nil
            } catch {
                logger.error("Failed to resolve thread-safe reference: \(error)")
                return nil
            }
        }
    }
    
    
    
  
    func addSyncedNodeAsync(_ node: SyncedNode) async throws {
        let nodeData = SyncedNodeData(from: node)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            realmQueue.async { [self] in
                do {
                    let realm = try getRealm()
                    let newNode = nodeData.toSyncedNode()
                    try realm.write {
                        realm.add(newNode)
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: BackupUploadError.CannotAddNodeToRealm)
                }
            }
        }
    }
    
    func editSyncedNodeDateAsync(remoteUuid: String, date: Date) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            realmQueue.async { [self] in
                do {
                    let realm = try getRealm()
                    
                    guard let node = realm.objects(SyncedNode.self).first(where: { syncedNode in
                        syncedNode.remoteUuid == remoteUuid
                    }) else {
                        continuation.resume(throwing: BackupUploadError.CannotFindNodeToRealm)
                        return
                    }
                    
                    try realm.write {
                        node.updatedAt = date
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: BackupUploadError.CannotEditNodeToRealm)
                }
            }
        }
    }
}


private struct SyncedNodeData {
    let remoteId: Int
    let deviceId: Int
    let remoteUuid: String
    let url: String
    let rootBackupFolder: String
    let parentId: String?
    let remoteParentId: Int?
    let createdAt: Date
    let updatedAt: Date
    
    init(from node: SyncedNode) {
        self.remoteId = node.remoteId
        self.deviceId = node.deviceId
        self.remoteUuid = node.remoteUuid
        self.url = node.url
        self.rootBackupFolder = node.rootBackupFolder
        self.parentId = node.parentId
        self.remoteParentId = node.remoteParentId
        self.createdAt = node.createdAt
        self.updatedAt = node.updatedAt
    }
    
    func toSyncedNode() -> SyncedNode {
        let node = SyncedNode()
        node.remoteId = remoteId
        node.deviceId = deviceId
        node.remoteUuid = remoteUuid
        node.url = url
        node.rootBackupFolder = rootBackupFolder
        node.parentId = parentId
        node.remoteParentId = remoteParentId
        node.createdAt = createdAt
        node.updatedAt = updatedAt
        return node
    }
}

