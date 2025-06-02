//
//  FolderMetaCache.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 2/6/25.
//

import Foundation

actor FolderMetaCache {
    private var meta: [String: (value: String, expiration: Date)] = [:]
    private var inProgress: [String: [CheckedContinuation<String, Error>]] = [:]
    
    private let ttl: TimeInterval = 500
    private let maxEntries = 5000

    func getOrFetch(for id: String, fetch: @escaping () async throws -> String, callId: String? = nil) async throws -> String {
        let now = Date()

        if let entry = meta[id], entry.expiration > now {
            return entry.value
        } else {
            meta[id] = nil
        }


        if inProgress[id] != nil {
            return try await withCheckedThrowingContinuation { continuation in
                inProgress[id]?.append(continuation)
            }
        }

        inProgress[id] = []

        do {
            let result = try await fetch()

            if meta.count >= maxEntries {
                removeExpiredEntries()
            }

            meta[id] = (value: result, expiration: now.addingTimeInterval(ttl))

            inProgress[id]?.forEach { $0.resume(returning: result) }
            inProgress[id] = nil
            return result
        } catch {
            inProgress[id]?.forEach { $0.resume(throwing: error) }
            inProgress[id] = nil
            throw error
        }
    }

    private func removeExpiredEntries() {
        let now = Date()
        meta = meta.filter { $0.value.expiration > now }

        if meta.count > maxEntries {
            let sorted = meta.sorted { $0.value.expiration < $1.value.expiration }
            let toRemove = sorted.prefix(meta.count - maxEntries)
            for (key, _) in toRemove {
                meta.removeValue(forKey: key)
            }
        }
    }
}
