//
//  BookmarkManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 27/1/25.
//

import Foundation

class BookmarkManager {
    static let shared = BookmarkManager()
    
    private let bookmarkKey = "bookmarkURL"
    
    private init() {}
    
    func saveBookmark(url: URL) throws {
        let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                               includingResourceValuesForKeys: nil,
                                               relativeTo: nil)
        UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
    }
    
    func resolveBookmark() -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                              options: [.withSecurityScope],
                              relativeTo: nil,
                              bookmarkDataIsStale: &isStale)
            
            if isStale {
                appLogger.info("bookmark is not updated.")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return nil
            }
            
            if url.startAccessingSecurityScopedResource() {
                return url
            } else {
                appLogger.info("Error accesing to URL")
                return nil
            }
        } catch {
            appLogger.info("Error resolving bookmark: \(error)")
            return nil
        }
    }
    
    func stopAccessing(url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
