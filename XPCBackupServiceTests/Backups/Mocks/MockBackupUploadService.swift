//
//  MockBackupUploadService.swift
//  InternxtDesktopTests
//
//  Created by Patricio Tovar on 18/6/24.
//

import Foundation

class MockBackupUploadService: BackupUploadServiceProtocol, @unchecked Sendable {
    private let lock = NSLock()

    private var _canDoBackup: Bool = true
    var canDoBackup: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _canDoBackup
    }

    private var _syncResult: Result<BackupTreeNodeSyncResult, Error>? = nil
    var syncResult: Result<BackupTreeNodeSyncResult, Error>? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _syncResult
        }
        set {
            lock.lock()
            _syncResult = newValue
            lock.unlock()
        }
    }

    private var _doSyncCallCount: Int = 0
    var doSyncCallCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _doSyncCallCount
    }

    private var _stopSyncCalled: Bool = false
    var stopSyncCalled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _stopSyncCalled
    }

    private var _syncDelayNanoseconds: UInt64 = 0
    var syncDelayNanoseconds: UInt64 {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _syncDelayNanoseconds
        }
        set {
            lock.lock()
            _syncDelayNanoseconds = newValue
            lock.unlock()
        }
    }

    private func recordSyncAttempt() -> (canDo: Bool, delay: UInt64, overrideResult: Result<BackupTreeNodeSyncResult, Error>?) {
        lock.lock()
        defer { lock.unlock() }
        _doSyncCallCount += 1
        return (_canDoBackup, _syncDelayNanoseconds, _syncResult)
    }

    func doSync(node: BackupTreeNode) async -> Result<BackupTreeNodeSyncResult, Error> {
        let (currentCanDoBackup, delay, resultOverride) = recordSyncAttempt()

        guard currentCanDoBackup else {
            node.removeChildNodes()
            return .failure(BackupUploadError.BackupStoppedManually)
        }

        if delay > 0 {
            try? await Task.sleep(nanoseconds: delay)
        }

        if let result = resultOverride {
            return result
        }
        if node.type == .folder {
            return .success(BackupTreeNodeSyncResult(id: 100, uuid: nil))
        }
        return .success(BackupTreeNodeSyncResult(id: 100, uuid: "ABC123456"))
    }

    func stopSync() {
        lock.lock()
        _stopSyncCalled = true
        _canDoBackup = false
        lock.unlock()
    }

    func reset() {
        lock.lock()
        _canDoBackup = true
        _syncResult = nil
        _doSyncCallCount = 0
        _stopSyncCalled = false
        _syncDelayNanoseconds = 0
        lock.unlock()
    }
}
