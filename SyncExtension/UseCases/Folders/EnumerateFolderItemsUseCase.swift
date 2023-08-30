//
//  EnumerateFolderItemsUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

struct EnumerateFolderItemsUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "EnumerateFolderItems")
    private let observer: NSFileProviderEnumerationObserver
    private let page: NSFileProviderPage
    private let driveAPI: DriveAPI = APIFactory.DriveNew
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let user: DriveUser
    init(user: DriveUser, enumeratedItemIdentifier: NSFileProviderItemIdentifier, for observer: NSFileProviderEnumerationObserver, from page: NSFileProviderPage) {
        self.observer = observer
        self.page = page
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.user = user
    }
    
    public func run(limit: Int = 50, offset: Int = 0) -> Void {
        Task {
            do {
                self.logger.info("Fetching folder content: \(self.enumeratedItemIdentifier.rawValue)")
                
                let folderId = self.enumeratedItemIdentifier == .rootContainer ? user.root_folder_id.toString() : self.enumeratedItemIdentifier.rawValue
                var items: Array<NSFileProviderItem> = Array()
                
                let folders = try await driveAPI.getFolderFolders(folderId: folderId, offset: offset, limit: limit , debug: true)
                self.logger.info("FOLDERS OK")
                let files = try await driveAPI.getFolderFiles(folderId: folderId, offset: offset, limit: limit)
                
                
                
                let hasMoreFiles = files.result.count == limit;
                let hasMoreFolders = folders.result.count == limit
                
                
                
                folders.result.forEach{ (folder) in
                    guard let createdAt = Time.dateFromISOString(folder.createdAt) else {
                        self.logger.error("Cannot create createdAt date for item \(folder.id) with value \(folder.createdAt)")
                        return
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(folder.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for item \(folder.id) with value \(folder.updatedAt)")
                        return
                    }
                    
                    
                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(folder.id)),
                        filename: FileProviderItem.getFilename(name: folder.plainName ?? folder.name , itemExtension: nil),
                        parentId: self.enumeratedItemIdentifier,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: nil,
                        itemType: .folder
                    )
                    items.append(item)
                }
                
                files.result.forEach{ (file) in
                    guard let createdAt = Time.dateFromISOString(file.createdAt) else {
                        self.logger.error("Cannot create createdAt date for item \(file.fileId) with value \(file.createdAt)")
                        return
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(file.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for item \(file.fileId) with value \(file.updatedAt)")
                        return
                    }
                    
                    

                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(file.uuid)),
                        filename: FileProviderItem.getFilename(name: file.plainName ?? file.name , itemExtension: file.type) ,
                        parentId: self.enumeratedItemIdentifier,
                        createdAt: createdAt,
                        updatedAt: updatedAt,
                        itemExtension: file.type,
                        itemType: .file,
                        size: Int(file.size) ?? 0
                    )
                    
                    items.append(item)
                }
                
                
                self.observer.didEnumerate(items)
                self.logger.info("✅ Enumerated items correctly for container \(self.enumeratedItemIdentifier.rawValue)")

                if hasMoreFiles || hasMoreFolders {
                    let nextOffset = limit + offset
                    // The next page is the offset we reached at the end of this page
                    observer.finishEnumerating(upTo: NSFileProviderPage(rawValue: Data(String(nextOffset).utf8)))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                
                
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Got error fetching folder content: \(error)")
                observer.finishEnumeratingWithError(error)
            }
        }
    }
}

