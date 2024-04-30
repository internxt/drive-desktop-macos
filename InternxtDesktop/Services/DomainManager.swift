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
    }
    
    mutating func exitDomain() async {
        self.manager = nil
        self.managerDomain = nil
        try? await NSFileProviderManager.removeAllDomains()
    }
}
