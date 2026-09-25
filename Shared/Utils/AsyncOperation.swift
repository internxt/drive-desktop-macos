//
//  AsyncOperation.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 27/5/24.
//

import Foundation
class AsyncOperation: Operation, @unchecked Sendable {
    
    private let stateLock = NSRecursiveLock()
    
    private var _isExecuting: Bool = false
    override var isExecuting: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isExecuting
        }
        set {
            willChangeValue(forKey: "isExecuting")
            stateLock.lock()
            _isExecuting = newValue
            stateLock.unlock()
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            stateLock.lock()
            defer { stateLock.unlock() }
            return _isFinished
        }
        set {
            willChangeValue(forKey: "isFinished")
            stateLock.lock()
            _isFinished = newValue
            stateLock.unlock()
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override func start() {
        if isCancelled {
            isExecuting = false
            isFinished = true
            return
        }
        
        isExecuting = true
        main()
    }
    
    override func main() {
        
        Task {
            do {
                try await performAsyncTask()
                self.finish()
            } catch {
                self.finish()
                print("Failed to perform async task", error)
            }
            
        }
        
    }
    
    func performAsyncTask() async throws -> Void {
        // Override this method in subclasses to perform the actual async work.
    }
    
    func finish() {
        isExecuting = false
        // Setting isFinished = true triggers KVO, which Foundation uses
        // to execute the completionBlock. This guarantees that completionBlock
        // is always called regardless of success, failure, or cancellation.
        isFinished = true
    }
}
