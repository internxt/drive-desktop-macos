//
//  DomainManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import Foundation
import FileProvider


struct DomainSyncEntry: Identifiable {
    let id: String
    
    let filename: String
    
    init(id: String, filename: String) {
        self.id = id
        self.filename = filename
    }
}

class DomainManager: ObservableObject {
    var manager: NSFileProviderManager
    var domain: NSFileProviderDomain
    @Published var syncEntries: [DomainSyncEntry] = []
    @objc dynamic var uploadProgress: Progress?
    @objc dynamic var downloadProgress: Progress?
    @objc class var keyPathsForValuesAffectingStatus: Set<String> {
        Set(["uploadProgress.fractionCompleted", "downloadProgress.fractionCompleted",
             "uploadProgress.fileTotalCount", "downloadProgress.fileTotalCount",
             "uploadProgress.fileCompletedCount", "downloadProgress.fileCompletedCount",
             "uploadProgress.totalUnitCount", "downloadProgress.totalUnitCount"])
        
    }
    
    init(domain: NSFileProviderDomain, uploadProgress: Progress?, downloadProgress: Progress?) {
        self.domain = domain
        self.uploadProgress = uploadProgress
        self.downloadProgress = downloadProgress
        self.manager = NSFileProviderManager(for: domain)!
    }
}
