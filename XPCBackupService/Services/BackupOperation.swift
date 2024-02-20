//
//  BackupOperation.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/20/24.
//

import Foundation

final class BackupOperation: BlockOperation, Completable, Enqueueable {
    var result: String?
    var lastError: Error?

    init(node: BackupTreeNode, attempLimit: Int) {
        super.init()
        addExecutionBlock { [weak self] in
            for _ in 1...attempLimit {
                Task {
                    do {
                        // do backend call to sync file or folder
                        return
                    } catch {
                        self?.lastError = error
                    }
                }
            }
        }
    }
}
