//
//  Debouncer.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 26/7/24.
//

import Foundation

class Debouncer {
    
    private let delay: TimeInterval
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private var lastExecutionTime: Date?

    init(delay: TimeInterval, queue: DispatchQueue = DispatchQueue.main) {
        self.delay = delay
        self.queue = queue
    }
    
    func debounce(action: @escaping (() -> Void)) {
        let now = Date()
        if let lastExecution = lastExecutionTime {
            if now.timeIntervalSince(lastExecution) < delay {
                return
            }
        }
        lastExecutionTime = now
        action()
    }
}
