//
//  BackupOperation.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/16/24.
//

import Foundation

class BackupOperation: BlockOperation, Completable, Enqueueable {
    var result: (URLResponse, Data)?
    var lastError: Error?

    init(node: BackupTreeNode, attempLimit: Int) {
        super.init()
        addExecutionBlock { [weak self] in
            for _ in 1...attempLimit {
                Task {
                    do {
                        // do backend call to upload file or folder
                        return
                    } catch {
                        print("error", error.localizedDescription)
                        self?.lastError = error
                    }
                }
            }
        }
    }
}
