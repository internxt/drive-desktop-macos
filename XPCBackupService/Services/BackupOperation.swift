//
//  BackupOperation.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/16/24.
//

import Foundation

final class BackupOperation: BlockOperation, Completable, Enqueueable {
    var result: (URLResponse, Data)?
    var lastError: Error?

    init(node: BackupTreeNode, attempLimit: Int) {
        super.init()
        addExecutionBlock { [weak self] in
            for _ in 1...attempLimit {
                do {
                    let request = URLRequest(url: URL(string: "")!)
                    var response: URLResponse?
                    let data = try NSURLConnection.sendSynchronousRequest(request, returning: &response)
                    self?.result = (response!, data)
                    return
                } catch {
                    self?.lastError = error
                }
            }
        }
    }
}
