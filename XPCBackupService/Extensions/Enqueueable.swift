//
//  Enqueueable.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/15/24.
//

import Foundation

protocol Enqueueable {
    func enqueue(in queue: OperationQueue) -> Self
}

extension Enqueueable where Self: Operation {
    func enqueue(in queue: OperationQueue) -> Self {
        queue.addOperation(self)
        return self
    }
}
