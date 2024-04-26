//
//  DomainManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import Foundation
import FileProvider
import os.log
import InternxtSwiftCore

struct DomainSyncEntry: Identifiable {
    let id: String
    
    let filename: String
    
    init(id: String, filename: String) {
        self.id = id
        self.filename = filename
    }
}

struct DomainManager {
    let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "DomainManager")
    lazy var manager: NSFileProviderManager? = nil
    var managerDomain: NSFileProviderDomain? = nil
    let resetDomainOnStart: Bool = ConfigLoader.isDevMode ? true : false
    
    private func getDomains() async throws -> [NSFileProviderDomain] {
        try await NSFileProviderManager.domains()
    }
    
    public mutating func initFileProviderForUser(user: DriveUser) async throws {
        

        let identifier = NSFileProviderDomainIdentifier(rawValue: user.uuid)
        let domain = NSFileProviderDomain(identifier: identifier, displayName: "")
        
        try await NSFileProviderManager.add(domain)
                
        self.manager = NSFileProviderManager(for: domain)
        self.managerDomain = domain
        self.logger.info("📦 FileProvider domain is ready with identifier \(identifier.rawValue )")
        return
        /*
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
                if #available(macOS 12.0, *) {
                    try await NSFileProviderManager.remove(loadedDomain, mode: .removeAll)
                } else {
                    try await NSFileProviderManager.remove(loadedDomain)
                }
                self.logger.info("Domain removed")
                
                self.logger.info("Domain added successfully")
                self.manager = NSFileProviderManager(for: newDomain)
                self.managerDomain = newDomain
            } else {
                try await NSFileProviderManager.add(loadedDomain)
                self.logger.info("Domain added successfully")
                self.manager = NSFileProviderManager(for: loadedDomain)
                self.managerDomain = loadedDomain
            }
            
        }*/
    }
    
    mutating func exitDomain() async throws {
        if let domain = self.managerDomain {
            try await NSFileProviderManager.remove(domain)
        }
        self.manager = nil
        self.managerDomain = nil
    }
}
