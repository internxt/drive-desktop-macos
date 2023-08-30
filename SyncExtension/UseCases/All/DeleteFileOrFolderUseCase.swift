//
//  DeleteFileOrFolderUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 24/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log

struct DeleteFileOrFolderUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "DeleteFileOrFolder")
    private let driveAPI: DriveAPI = APIFactory.Drive
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let completionHandler: (Error?) -> Void
    private let identifier: NSFileProviderItemIdentifier
    private let user: DriveUser
    init(user: DriveUser,identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        self.completionHandler = completionHandler
        self.identifier = identifier
        self.user = user
    }
    
    
    func run() {
        //GetFileOrFolderMetaUseCase(user: user, identifier: identifier, completionHandler: )
    }
    
    private func onFileProviderItemRetrieved(fileProviderItem: NSFileProviderItem) {
        Task {
            
            
        }
        
        
    }
}
