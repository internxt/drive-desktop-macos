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
            self.cleanupIfNeeded()
            self.deletedFolders[folderId] = expiration
        }
    }

    func isFolderDeleted(_ folderId: String) -> Bool {
        var isDeleted = false
        let now = Date()

        queue.sync {
            if let expiration = self.deletedFolders[folderId], expiration > now {
                isDeleted = true
            } else {
                self.deletedFolders.removeValue(forKey: folderId)
            }
        }

        return isDeleted
    }

   
    private func cleanupIfNeeded() {
        if deletedFolders.count > maxEntries {
            let now = Date()
            deletedFolders = deletedFolders.filter { $0.value > now }
        }
    }
}
