//
//  DeletedItemsCache.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 2/6/25.
//

import Foundation


final class DeletedFolderCache {
    static let shared = DeletedFolderCache()

    private let ttl: TimeInterval = 300
    private let maxEntries = 5000

    private var deletedFolders: [String: Date] = [:]
    private let queue = DispatchQueue(label: "DeletedFolderCacheQueue", attributes: .concurrent)

    private init() {}

    func markFolderAsDeleted(_ folderId: String) {
        let expiration = Date().addingTimeInterval(ttl)
        queue.async(flags: .barrier) {
            self.cleanupExpiredEntries()
            self.deletedFolders[folderId] = expiration
            if self.deletedFolders.count > self.maxEntries {
                let sortedEntries = self.deletedFolders.sorted { $0.value < $1.value }
                let toRemove = sortedEntries.prefix(self.deletedFolders.count - self.maxEntries)
                toRemove.forEach { self.deletedFolders.removeValue(forKey: $0.key) }
            }
        }
    }

    func isFolderDeleted(_ folderId: String) -> Bool {
        return queue.sync {
            
            let now = Date()
            if let expiration = self.deletedFolders[folderId] {
                return expiration > now
            }
            return false
        }
    }

    func removeFolder(_ folderId: String) {
        queue.async(flags: .barrier) {
            self.deletedFolders.removeValue(forKey: folderId)
        }
    }
   
    private func cleanupExpiredEntries() {
        let now = Date()
        deletedFolders = deletedFolders.filter { $0.value > now }
    }
}
