//
//  GetFileItemUseCase.swift
//  SyncExtension
//
//  Created by Patricio Tovar on 23/5/24.
//

import Foundation
import InternxtSwiftCore
import FileProvider

struct GetItemMetaUseCase {
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    
    init() {
        
    }
    
    
    public func fetchFileOrFolderItem(identifier: NSFileProviderItemIdentifier) async throws -> GetDriveItemMetaByIdResponse {
        do {
            
            return try await driveNewAPI.getFolderOrFileMetaById(id: identifier.rawValue)
            
        } catch {
            error.reportToSentry()
            throw NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue)
        }
    }
}

