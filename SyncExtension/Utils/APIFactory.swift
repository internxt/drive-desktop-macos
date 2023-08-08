//
//  APIFactory.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/8/23.
//

import Foundation
import InternxtSwiftCore

enum APIFactoryError: Error {
    case MissingLegacyToken
}
struct APIFactory {
    
    static var Drive: DriveAPI {
        let configLoader = ConfigLoader()
        
        let config = configLoader.get()
        let token = configLoader.getLegacyAuthToken() ?? "MISSING_TOKEN"
        
        return DriveAPI(baseUrl: config.DRIVE_API_URL, authToken: token)
    }
}
