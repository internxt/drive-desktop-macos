//
//  DomainManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import Foundation
import FileProvider
import os.log

struct DomainSyncEntry: Identifiable {
    let id: String
    
    let filename: String
    
    init(id: String, filename: String) {
        self.id = id
        self.filename = filename
    }
}

struct DomainManager {
    let logger = Logger(subsystem: "com.internxt", category: "DomainManager")
    lazy var manager: NSFileProviderManager? = nil
    var managerDomain: NSFileProviderDomain? = nil
    let resetDomainOnStart: Bool = true
    
    private func getDomains() async throws -> [NSFileProviderDomain] {
        try await NSFileProviderManager.domains()
    }
    
    public mutating func initFileProvider() async throws {
        
        let identifier = NSFileProviderDomainIdentifier(rawValue:  NSUUID().uuidString)
        let newDomain = NSFileProviderDomain(identifier: identifier, displayName: "")
        
        let domains = try await self.getDomains()
        
        let firstDomain = domains.first
        let noDomain = firstDomain == nil
        
        if noDomain {
            self.logger.info("No domain was found, adding one")
            try await NSFileProviderManager.add(newDomain)
            self.logger.info("Domain added successfully")
            self.manager = NSFileProviderManager(for: newDomain)
            self.managerDomain = newDomain
        }
        
        if let loadedDomain = firstDomain {
            
            if self.resetDomainOnStart {
                self.logger.info("Resetting domain on start")
                try await NSFileProviderManager.remove(loadedDomain, mode: .removeAll)
                self.logger.info("Domain removed")
                try await NSFileProviderManager.add(newDomain)
                self.logger.info("Domain added successfully")
                self.manager = NSFileProviderManager(for: newDomain)
                self.managerDomain = newDomain
            } else {
                try await NSFileProviderManager.add(loadedDomain)
                self.logger.info("Domain added successfully")
                self.manager = NSFileProviderManager(for: loadedDomain)
                self.managerDomain = loadedDomain
            }
            
        }
    }
    
    func exitDomain() async throws {
        if let domain = self.managerDomain {
            try await NSFileProviderManager.remove(domain)
        }
    }
}
