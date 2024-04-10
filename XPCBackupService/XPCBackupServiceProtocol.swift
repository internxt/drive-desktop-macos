//
//  XPCBackupServiceProtocol.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation

@objc protocol XPCBackupServiceProtocol {
    
    func startBackup(backupAt backupURLs: [String], mnemonic: String, networkAuth: String?, authToken: String, newAuthToken: String, deviceId: Int, bucketId: String, with reply: @escaping (_ result: String?, _ error: String?) -> Void)

    func stopBackup()
    
    func getBackupStatus(with reply: @escaping (_ result: BackupProgressUpdate?, _ error: String?) -> Void)

}

/*
 To use the service from an application or other process, use NSXPCConnection to establish a connection to the service by doing something like this:

     connectionToService = NSXPCConnection(serviceName: "com.internxt.XPCBackupService")
     connectionToService.remoteObjectInterface = NSXPCInterface(with: XPCBackupServiceProtocol.self)
     connectionToService.resume()

 Once you have a connection to the service, you can use it like this:

     if let proxy = connectionToService.remoteObjectProxy as? XPCBackupServiceProtocol {
         proxy.performCalculation(firstNumber: 23, secondNumber: 19) { result in
             NSLog("Result of calculation is: \(result)")
         }
     }

 And, when you are finished with the service, clean up the connection like this:

     connectionToService.invalidate()
*/
