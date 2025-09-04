//
//  HelperServiceManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import Foundation
import ServiceManagement

class HelperServiceManager: ServiceManaging {
    private let helperServiceName: String
    private let plistName: String
    
    init(serviceName: String) {
        self.helperServiceName = serviceName
        self.plistName = serviceName + ".plist"
    }
    
    private var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }
    
    func registerHelper() throws {
        try service.register()
    }
    
    func unregisterHelper() throws {
        try service.unregister()
    }
    
    func getHelperStatus() -> SMAppService.Status {
        return service.status
    }
}

class XPCDataManager {
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func encode<T: Codable>(_ object: T) throws -> Data {
        return try encoder.encode(object)
    }
    
    func decode<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        return try decoder.decode(type, from: data)
    }
}

