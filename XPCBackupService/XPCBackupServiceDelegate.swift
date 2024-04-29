//
//  XPCBackupServiceDelegate.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation

class XPCBackupServiceDelegate: NSObject, NSXPCListenerDelegate {
    let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "XPCBackupServiceDelegate")
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        ErrorUtils.start()
        
        let exportedOption = XPCBackupService()
        newConnection.exportedInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
        newConnection.exportedObject = exportedOption
        newConnection.resume()
        return true
    }
}
