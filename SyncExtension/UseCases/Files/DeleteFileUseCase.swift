//
//  DeleteFileUseCase.swift
//  SyncExtension
//
//  Created by Robert Garcia on 26/9/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore



struct DeleteFileUseCase {
    let logger = syncExtensionLogger
    private let trashAPI: TrashAPI = APIFactory.Trash
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    private let identifier: NSFileProviderItemIdentifier
    private let completionHandler: (Error?) -> Void

    init(identifier: NSFileProviderItemIdentifier, completionHandler: @escaping (Error?) -> Void) {
        self.identifier = identifier
        self.completionHandler = completionHandler
    }
    
    public func run( ) -> Progress {
        Task {
            do {
                self.logger.info("Deleting file with id \(identifier.rawValue)")
                let _ = try await DriveFileService.shared.trashFile(uuid: identifier.rawValue)
                self.logger.info("✅ File with id \(identifier.rawValue) deleted correctly")
                completionHandler(nil)
            } catch {
                self.logger.error("❌ Failed to delete file: \(error.getErrorDescription())")
                completionHandler(NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue))
            }
        }
        return Progress()
    }
}
