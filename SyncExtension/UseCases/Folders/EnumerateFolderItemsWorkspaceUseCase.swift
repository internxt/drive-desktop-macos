//
//  EnumerateFolderItemsWorkspaceUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 8/11/24.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

struct EnumerateFolderItemsWorkspaceUseCase {
    let logger = syncExtensionLogger
    private let observer: NSFileProviderEnumerationObserver
    private let page: NSFileProviderPage
    private let driveAPI: DriveAPI = APIFactory.DriveNew
    private let enumeratedItemIdentifier: NSFileProviderItemIdentifier
    private let user: DriveUser
    private let workspace: [AvailableWorkspace]
    init(user: DriveUser, enumeratedItemIdentifier: NSFileProviderItemIdentifier, for observer: NSFileProviderEnumerationObserver, from page: NSFileProviderPage,workspace:[AvailableWorkspace]) {
        self.observer = observer
        self.page = page
        self.enumeratedItemIdentifier = enumeratedItemIdentifier
        self.user = user
        self.workspace = workspace
    }
    
    private func getOffset() -> Int {
        let isInitial: Bool = self.page == NSFileProviderPage.initialPageSortedByDate as NSFileProviderPage || self.page == NSFileProviderPage.initialPageSortedByName as NSFileProviderPage
        
        if isInitial {
            return 0
        } else {
            guard let offsetString = String(data: self.page.rawValue, encoding: .utf8) else {
                return 0
            }
            
            guard let offset = Int(offsetString) else {
                return 0
            }
            
            return offset
        }
    }
    public func run(limit: Int = 50) -> Void {
        Task {
            do {
                
                guard !workspace.isEmpty else {
                    self.logger.error("Workspace array is empty, cannot proceed with item access.")
                    return
                }

                let workspaceId = workspace[0].workspaceUser.workspaceId
                let rootFolderUuid = workspace[0].workspaceUser.rootFolderId
                
                self.logger.info("Fetching folder content: \(self.enumeratedItemIdentifier.rawValue) Workspace: \(workspaceId)")
                
                let folderId = self.enumeratedItemIdentifier == .rootContainer ? rootFolderUuid : self.enumeratedItemIdentifier.rawValue
                var items: Array<NSFileProviderItem> = Array()
                
                
                let folders = try await driveAPI.getFolderFoldersWorkspace(workspaceId: workspaceId, folderId: folderId,offset: self.getOffset(),limit: limit)
                
                
                let files = try await driveAPI.getFolderFilesWorkspace(workspaceId: workspaceId, folderId: folderId,offset: self.getOffset(),limit: limit)
                
                
                
                let hasMoreFiles = files.result.count == limit;
                let hasMoreFolders = folders.result.count == limit
                
                
                
                folders.result.forEach{ (folder) in
                    if folder.status != "EXISTS" {
                        return
                    }
                    
                    guard let createdAt = Time.dateFromISOString(folder.createdAt) else {
                        self.logger.error("Cannot create createdAt date for item \(folder.id) with value \(folder.createdAt)")
                        return
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(folder.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for item \(folder.id) with value \(folder.updatedAt)")
                        return
                    }
                    
                    // change id by uuid
                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: folder.uuid ?? String(folder.id)),
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
                    if file.status != "EXISTS" {
                        return
                    }
                    
                    guard let createdAt = Time.dateFromISOString(file.createdAt) else {
                        self.logger.error("Cannot create createdAt date for item \(file.fileId) with value \(file.createdAt)")
                        return
                    }
                    
                    guard let updatedAt = Time.dateFromISOString(file.updatedAt) else {
                        self.logger.error("Cannot create updatedAt date for item \(file.fileId) with value \(file.updatedAt)")
                        return
                    }
                    
                    

                    let filename = FileProviderItem.getFilename(name: file.plainName ?? file.name , itemExtension: file.type
                    )
                    
                    let item = FileProviderItem(
                        identifier: NSFileProviderItemIdentifier(rawValue: String(file.uuid)),
                        filename: filename,
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
                    let nextOffset = limit + getOffset()
                    self.logger.info("There are more files and folders, current offset is \(nextOffset)")
                    // The next page is the offset we reached at the end of this page
                    observer.finishEnumerating(upTo: NSFileProviderPage(rawValue: Data(String(nextOffset).utf8)))
                } else {
                    observer.finishEnumerating(upTo: nil)
                }
                
                
                
            } catch {
                error.reportToSentry()
                self.logger.error("❌ Got error fetching folder content: \(error.getErrorDescription())")
                observer.finishEnumeratingWithError(error)
            }
        }
    }
}


