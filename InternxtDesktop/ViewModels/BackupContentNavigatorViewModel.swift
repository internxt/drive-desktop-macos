//
//  BackupContentNavigatorViewModel.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 26/7/24.
//

import Foundation
import SwiftUI
import InternxtSwiftCore

struct BackupContentItem {
    var id: String
    var name: String
    var type: String
    var uuid: String
}

struct BackupNavigationLevel {
    var id: String
    var uuid: String?
    var name: String
}

enum BackupContentNavigatorError: Error {
    case NavigationLevelAlreadyExists
}
let LIMIT_PER_REQUEST = 50

extension BackupContentNavigator {
    class ViewModel: ObservableObject {
        private let decrypt = Decrypt()
        private let backupAPI = APIFactory.BackupNew
        var inMemoryItems: [Int: [BackupContentItem]] = [:]
        @Published var loadingItems: Bool = false
        @Published var currentItems: [BackupContentItem] = []
        @Published var folderError: (any Error)? = nil
        @Published var navigationLevels: [BackupNavigationLevel] = []
 
        
        func loadMoreForFolderId(folderId: Int, bucketId: String) async throws {
            let currentFiles = currentItems.filter{$0.type != "folder"}
            let currentChilds = currentItems.filter{$0.type == "folder"}
            
            var moreChilds: [BackupContentItem] = []
            var moreFiles: [BackupContentItem] = []
            
            let needsMoreFiles = currentFiles.count >= LIMIT_PER_REQUEST
            let needsMoreChilds = currentChilds.count >= LIMIT_PER_REQUEST
            
            if needsMoreFiles || needsMoreChilds {
                let folderMeta = try await backupAPI.getBackupFolderMeta(folderId: folderId.toString())
                
                guard let folderUuid = folderMeta.uuid else {
                    return
                }
                
                if needsMoreFiles {
                    moreFiles = try await self.getFolderFilesAsBackupContentItems(folderUuid: folderUuid, bucketId: bucketId, offset: currentFiles.count, limit: LIMIT_PER_REQUEST)
                }
                
                if needsMoreChilds {
                    moreChilds = try await self.getFolderChildsAsBackupContentItems(folderUuid: folderUuid, bucketId: bucketId, offset: currentChilds.count, limit: LIMIT_PER_REQUEST)
                }
                
                let newItems = self.currentItems + moreFiles + moreChilds
                
                DispatchQueue.main.async {
                    self.currentItems = newItems
                }
            }
        }
        
        
        func loadFolderContent(folderName: String, folderId: Int, bucketId: String) async throws -> Void {
            do {
                
                let folderMeta = try await backupAPI.getBackupFolderMeta(folderId: folderId.toString())

                guard let folderUuid = folderMeta.uuid  else {
                    return
                }
                
                let levelExistsAlready = navigationLevels.contains{$0.id == folderId.toString()}
                if levelExistsAlready {
                    self.navigateToLevel(folderId: folderId.toString())
                } else {
                    self.addNavigationLevel(folderName: folderName, folderId: folderId.toString(), folderUuid: folderUuid)
                }
                
                DispatchQueue.main.sync {
                    self.folderError = nil
                    self.loadingItems = true
                    self.currentItems = []
                }
                                

                
                async let childs = try self.getFolderChildsAsBackupContentItems(folderUuid: folderUuid, bucketId: bucketId, offset: 0, limit: LIMIT_PER_REQUEST)
                async let files = try self.getFolderFilesAsBackupContentItems(folderUuid: folderUuid, bucketId: bucketId, offset: 0, limit: LIMIT_PER_REQUEST)
                
                let results = try await [childs, files]
                DispatchQueue.main.async {
                    let items = (results.first ?? []) + (results.last ?? [])
                    self.currentItems = items
                    self.inMemoryItems.updateValue(items, forKey: folderId)
                    self.loadingItems = false
                }
            } catch {
                appLogger.error(["Failed to load backup folder content", error])
                DispatchQueue.main.sync {
                    self.folderError = error
                }
            }
            
        }
        
    
        
        private func getFolderChildsAsBackupContentItems(folderUuid: String, bucketId: String, offset: Int, limit: Int) async throws -> [BackupContentItem] {
            let childs = try await backupAPI.getBackupChilds(folderUuid:folderUuid, offset: offset, limit: limit)
            
            return childs.folders.map { child in
                let name = child.plainName ?? self.decryptName(name: child.name, bucketId: bucketId)
                return BackupContentItem(id: child.id.toString(), name: name, type: "folder", uuid: child.uuid!)
            }
        }
        
        private func getFolderFilesAsBackupContentItems(folderUuid: String, bucketId: String, offset: Int, limit: Int) async throws -> [BackupContentItem] {
            let files = try await backupAPI.getBackupFiles(folderUuid: folderUuid, offset: offset, limit: limit)
            
            return files.files.map { file in
                let name = file.plainName ?? self.decryptName(name: file.name, bucketId: bucketId)
                return BackupContentItem(id: file.fileId, name: name, type: file.type ?? "", uuid: file.uuid)
            }
        }
        
        private func navigateToLevel(folderId: String) {
            if let index = navigationLevels.firstIndex(where: {$0.id == folderId}) {
                DispatchQueue.main.sync {
                    navigationLevels = Array(navigationLevels.prefix(upTo: index + 1))
                }
            }
        }
        
        private func addNavigationLevel(folderName: String, folderId: String, folderUuid: String?) {
            DispatchQueue.main.sync {
                navigationLevels.append(BackupNavigationLevel(
                    id: folderId,
                    uuid: folderUuid,
                    name: folderName
                ))
            }
        }
        
        private func decryptName(name: String, bucketId: String) -> String {
            return (try? decrypt.decrypt(base64String: name, password: DecryptUtils().getDecryptPassword(bucketId: bucketId))) ?? name
        }
        
        func getUUIDFromItem(forID id: String) -> String? {
            return currentItems.first(where: { $0.id == id })?.uuid
        }
    }
}



