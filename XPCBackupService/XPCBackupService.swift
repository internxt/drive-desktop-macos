//
//  XPCBackupService.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation

class XPCBackupService: NSObject, XPCBackupServiceProtocol {
    @objc func performCalculation(firstNumber: Int, secondNumber: Int, with reply: @escaping (Int) -> Void) {
        let response = firstNumber + secondNumber
        reply(response)
    }
    
    @objc func startBackup(backupAt backupURL: URL, with reply: @escaping () -> Void) {
        
        Task {
            let backupTreeGenerator = BackupTreeGenerator(root: backupURL)
            
            let backupTree = try await backupTreeGenerator.generateTree()
            
            try await backupTree.syncNodes()
            
            reply()
        }
        
    }
}
