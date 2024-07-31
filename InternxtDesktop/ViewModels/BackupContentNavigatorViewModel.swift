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
}

struct BackupNavigationLevel {
    var id: String
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
            if currentFiles.count >= LIMIT_PER_REQUEST {
                moreFiles = try await self.getFolderFilesAsBackupContentItems(folderId: folderId, bucketId: bucketId, offset: currentFiles.count, limit: LIMIT_PER_REQUEST)
            }
            
            if currentChilds.count >= LIMIT_PER_REQUEST {
                moreChilds =  try await self.getFolderChildsAsBackupContentItems(folderId: folderId, bucketId: bucketId, offset: currentChilds.count, limit: LIMIT_PER_REQUEST)
            }
            let newItems = self.currentItems + moreFiles + moreChilds
            
            DispatchQueue.main.async {
                self.currentItems = newItems
            }
        }
        
        
        func loadFolderContent(folderName: String, folderId: Int, bucketId: String) async throws -> Void {
            do {
                let levelExistsAlready = navigationLevels.contains{$0.id == folderId.toString()}
                if levelExistsAlready {
                    self.navigateToLevel(folderId: folderId.toString())
                } else {
                    self.addNavigationLevel(folderName: folderName, folderId: folderId.toString())
                }
                
                DispatchQueue.main.sync {
                    self.folderError = nil
                    self.loadingItems = true
                    self.currentItems = []
                }
                async let childs = try self.getFolderChildsAsBackupContentItems(folderId: folderId, bucketId: bucketId, offset: 0, limit: LIMIT_PER_REQUEST)
                async let files = try self.getFolderFilesAsBackupContentItems(folderId: folderId, bucketId: bucketId, offset: 0, limit: LIMIT_PER_REQUEST)
                
                let results = try await [childs, files]
                DispatchQueue.main.async {
                    let items = (results.first ?? []) + (results.last ?? [])
                    self.currentItems = items
                    self.inMemoryItems.updateValue(items, forKey: folderId)
                    self.loadingItems = false
                }
            } catch {
                DispatchQueue.main.sync {
                    self.folderError = error
                }
            }
            
        }
        
    
        
        private func getFolderChildsAsBackupContentItems(folderId: Int, bucketId: String, offset: Int, limit: Int) async throws -> [BackupContentItem]   {
            let childs = try await backupAPI.getBackupChilds(folderId: folderId.toString(), offset: offset, limit: limit)
            
            
            return childs.result.map{child in
                let name = child.plainName ?? self.decryptName(name: child.name, bucketId: bucketId)
                return BackupContentItem(id: child.id.toString(), name: name, type: "folder")
            }
        }
        
        private func getFolderFilesAsBackupContentItems(folderId: Int, bucketId: String, offset: Int, limit: Int) async throws -> [BackupContentItem] {
            let files = try await backupAPI.getBackupFiles(folderId: folderId.toString(), offset: offset, limit: limit)
            
            return files.result.map{file in
                let name = file.plainName ?? self.decryptName(name: file.name, bucketId: bucketId)
                return BackupContentItem(id: file.id.toString(),name: name, type: file.type ?? "")
            }
        }
        
        private func navigateToLevel(folderId: String) {
            if let index = navigationLevels.firstIndex(where: {$0.id == folderId}) {
                DispatchQueue.main.sync {
                    navigationLevels = Array(navigationLevels.prefix(upTo: index + 1))
                }
            }
        }
        
        private func addNavigationLevel(folderName: String, folderId: String) {
            DispatchQueue.main.sync {
                navigationLevels.append(BackupNavigationLevel(id: folderId, name: folderName))
            }
            
        }
        
        private func decryptName(name: String, bucketId: String) -> String {
            return (try? decrypt.decrypt(base64String: name, password: DecryptUtils().getDecryptPassword(bucketId: bucketId))) ?? name
        }
    }
}



