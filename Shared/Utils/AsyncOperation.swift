//
//  AsyncOperation.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 27/5/24.
//

import Foundation
class AsyncOperation: Operation {
    
    private let lockQueue = DispatchQueue(label: "com.internxt.AsyncOperation", attributes: .concurrent)
    
    private var _isExecuting: Bool = false
    override var isExecuting: Bool {
        get {
            return lockQueue.sync { _isExecuting }
        }
        set {
            willChangeValue(forKey: "isExecuting")
            lockQueue.sync(flags: .barrier) { _isExecuting = newValue }
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    private var _isFinished: Bool = false
    override var isFinished: Bool {
        get {
            return lockQueue.sync { _isFinished }
        }
        set {
            willChangeValue(forKey: "isFinished")
            lockQueue.sync(flags: .barrier) { _isFinished = newValue }
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    override func start() {
        if isCancelled {
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
        isFinished = true
    }
}
