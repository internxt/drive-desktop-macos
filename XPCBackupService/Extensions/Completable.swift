//
//  Completable.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/15/24.
//

import Foundation

protocol Completable {
    func addCompletionOperation(on queue: OperationQueue, complete: @escaping (Self) -> Void) -> Operation
}

extension Completable where Self: Operation {
    func addCompletionOperation(on queue: OperationQueue, complete: @escaping (Self) -> Void) -> Operation {
        let completionOperation = BlockOperation {
            complete(self)
        }
        completionOperation.addDependency(self)
        queue.addOperation(completionOperation)
        return completionOperation
    }
}


