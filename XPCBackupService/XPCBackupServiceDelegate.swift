//
//  XPCBackupServiceDelegate.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation

class XPCBackupServiceDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        let exportedOption = XPCBackupService.shared
        newConnection.exportedInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
        newConnection.exportedObject = exportedOption
        newConnection.resume()
        return true
    }
}
