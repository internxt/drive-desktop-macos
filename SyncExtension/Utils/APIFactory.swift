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
    
    
    static var Network: NetworkAPI {
        let configLoader = ConfigLoader()
        
        let config = configLoader.get()
        return NetworkAPI(baseUrl: config.NETWORK_API_URL, basicAuthToken: config.NETWORK_AUTH)
    }
    
    static var DriveNew: DriveAPI {
        let configLoader = ConfigLoader()
        
        let config = configLoader.get()
        let token = configLoader.getAuthToken() ?? "MISSING_TOKEN"
        
        return DriveAPI(baseUrl: config.DRIVE_NEW_API_URL, authToken: token)
    }
    
    static var Drive: DriveAPI {
        let configLoader = ConfigLoader()
        
        let config = configLoader.get()
        let token = configLoader.getLegacyAuthToken() ?? "MISSING_TOKEN"
        
        return DriveAPI(baseUrl: config.DRIVE_API_URL, authToken: token)
    }
    
    static var Trash: TrashAPI {
        let configLoader = ConfigLoader()
        
        let config = configLoader.get()
        let token = configLoader.getAuthToken() ?? "MISSING_TOKEN"
        
        return TrashAPI(baseUrl: config.DRIVE_NEW_API_URL, authToken: token)
    }
}
