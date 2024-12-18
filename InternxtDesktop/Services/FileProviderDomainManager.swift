//
//  FileProviderDomainManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import Foundation
import FileProvider
import os.log
import InternxtSwiftCore


enum FileProviderDomainStatus {
    case Idle
    case Ready
    case FailedToInitialize
    case Initializing
}
class FileProviderDomainManager: ObservableObject {
    let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "DomainManager")
    lazy var manager: NSFileProviderManager? = nil
    var managerDomain: NSFileProviderDomain? = nil
    @Published var domainStatus: FileProviderDomainStatus = .Idle
    
    private func getDomains() async throws -> [NSFileProviderDomain] {
        try await NSFileProviderManager.domains()
    }
    
    public func initFileProviderForUser(user: DriveUser) async throws {
        do {
            self.updateStatus(newStatus: .Initializing)
            let identifier = NSFileProviderDomainIdentifier(rawValue: user.uuid)
            let domain = NSFileProviderDomain(identifier: identifier, displayName: "")
            
            try await NSFileProviderManager.add(domain)
                    
            self.manager = NSFileProviderManager(for: domain)
            self.managerDomain = domain
            self.logger.info("📦 FileProvider domain is ready with identifier \(identifier.rawValue)")
            self.updateStatus(newStatus: .Ready)
            return
        } catch {
            self.updateStatus(newStatus: .FailedToInitialize)
            throw error
        }
    }
    
    public func retryFileProviderInit(user: DriveUser) async throws {
        try await NSFileProviderManager.removeAllDomains()
        try await self.initFileProviderForUser(user: user)
    }
    
    
    public func exitDomain() async {
        self.logger.info("🧹 Cleaning up FileProvider domain")
        if let domain = self.managerDomain {
            try? await NSFileProviderManager.remove(domain)
        }
        self.manager = nil
        self.managerDomain = nil
        try? await NSFileProviderManager.removeAllDomains()
    }
    
    
    private func updateStatus(newStatus: FileProviderDomainStatus) {
        DispatchQueue.main.async {
            self.domainStatus = newStatus
        }
    }
    
    public func initFileProviderForUserWorkspace(user: DriveUser, workspaces: [AvailableWorkspace]) async throws {
        do {
            if !workspaces.isEmpty{
                let identifier = NSFileProviderDomainIdentifier(rawValue: workspaces[0].workspaceUser.workspaceId)
                let domain = NSFileProviderDomain(identifier: identifier, displayName: "Internxt Business")
                
                try await NSFileProviderManager.add(domain)
                
                self.logger.info("📦 FileProvider domain workspace is ready with identifier \(identifier.rawValue)")
            }
        
            return
        } catch {
            throw error
        }
    }
}
