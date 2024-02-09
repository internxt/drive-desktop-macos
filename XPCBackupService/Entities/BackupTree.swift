//
//  BackupTree.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 9/2/24.
//

import Foundation

struct BackupTree: Identifiable {
    let backupPath: URL
    let id: ObjectIdentifier
    let remoteId: String
    let remoteParentId: String
    private(set) var childs: [BackupTreeNode]
    
    mutating func addChild(newNode: BackupTreeNode){
        childs.append(newNode)
    }
}
