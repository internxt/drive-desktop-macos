//
//  XPCCleanerConnectionManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import Foundation
import ServiceManagement

protocol XPCConnectionManaging {
    func createConnection() -> NSXPCConnection?
    func invalidateConnection()
}

protocol ServiceManaging {
    func registerHelper() throws
    func unregisterHelper() throws
    func getHelperStatus() -> SMAppService.Status
}

// MARK: - Models
enum XPCManagerState {
    case idle
    case connecting
    case scanning
    case cleaning
    case error(String)
}

// MARK: - Errors
enum XPCManagerError: LocalizedError {
    case connectionFailed
    case noRemoteProxy
    case encodingFailed
    case decodingFailed
    case helperNotAvailable
    case connectionTimeout
    case connectionLost
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "Failed to establish XPC connection"
        case .noRemoteProxy:
            return "No XPC remote proxy available"
        case .encodingFailed:
            return "Failed to encode data"
        case .decodingFailed:
            return "Failed to decode response"
        case .helperNotAvailable:
            return "Helper service is not available"
        case .connectionTimeout:
            return "XPC operation timed out"
        case .connectionLost:
            return "XPC connection was lost during operation"
        }
    }
}

// MARK: - XPC Connection Manager
class XPCCleanerConnectionManager: XPCConnectionManaging {
    private let serviceName: String
    private var connection: NSXPCConnection?
    
    init(serviceName: String) {
        self.serviceName = serviceName
    }
    
    func createConnection() -> NSXPCConnection? {
        let newConnection = NSXPCConnection(machServiceName: serviceName, options: .privileged)
        newConnection.remoteObjectInterface = NSXPCInterface(with: CleanerHelperXPCProtocol.self)
        
        newConnection.interruptionHandler = { [weak self] in
            print("XPC connection interrupted")
            self?.connection = nil
        }
        
        newConnection.invalidationHandler = { [weak self] in
            print("XPC connection invalidated")
            self?.connection = nil
        }
        
        newConnection.resume()
        self.connection = newConnection
        
        return newConnection
    }
    
    func invalidateConnection() {
        connection?.invalidate()
        connection = nil
    }
    
    deinit {
        invalidateConnection()
    }
}
