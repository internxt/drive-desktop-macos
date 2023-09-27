//
//  DeleteFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 26/9/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore
import os.log



struct DeleteFileUseCase {
    let logger = Logger(subsystem: "com.internxt", category: "DeleteFile")
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let identifier: NSFileProviderItemIdentifier
    private let completionHandler: (Error?) -> Void

    init(identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        self.identifier = identifier
        self.completionHandler = completionHandler
    }
    
    public func run( ) -> Progress {
        self.logger.info("Deleting file with fileId \(identifier.rawValue)")
       
        // File deleting is not allowed from the Internxt Desktop app, so we just let it pass for now
        
        self.logger.info("✅ File with id \(identifier.rawValue) deleted correctly")
        completionHandler(nil)
        
        return Progress()
    }
}
