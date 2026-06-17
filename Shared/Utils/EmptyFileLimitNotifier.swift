//
//  EmptyFileLimitNotifier.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 12/6/26.
//

import Foundation

public let NOTIFICATION_EMPTY_FILE_LIMIT = "com.internxt.drive.emptyFileLimitReached"
private let kEmptyFileLimit_firstFilename = "EmptyFileLimit_firstFilename"
private let kEmptyFileLimit_count         = "EmptyFileLimit_count"
private let kEmptyFileLimit_reason        = "EmptyFileLimit_reason"

private let _emptyFileLock = NSLock()

public enum EmptyFileLimitReason: String {
    case quotaExceeded  = "quotaExceeded"
    case planNotAllowed = "planNotAllowed"
}


public enum EmptyFileLimitNotifier {

    public static func post(filename: String, reason: EmptyFileLimitReason) {
        _emptyFileLock.lock()
        defer { _emptyFileLock.unlock() }

        let defaults = UserDefaults(suiteName: INTERNXT_GROUP_NAME)

        let previousCount = defaults?.integer(forKey: kEmptyFileLimit_count) ?? 0
        let newCount = previousCount + 1
        defaults?.set(newCount, forKey: kEmptyFileLimit_count)

       
        if previousCount == 0 {
            defaults?.set(filename,       forKey: kEmptyFileLimit_firstFilename)
            defaults?.set(reason.rawValue, forKey: kEmptyFileLimit_reason)
        }

        defaults?.synchronize()

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(NOTIFICATION_EMPTY_FILE_LIMIT),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }

    public static func readAndResetBatch() -> (rejectedCount: Int, firstFilename: String, reason: EmptyFileLimitReason) {
        let defaults = UserDefaults(suiteName: INTERNXT_GROUP_NAME)

        let count      = defaults?.integer(forKey: kEmptyFileLimit_count)              ?? 0
        let filename   = defaults?.string(forKey: kEmptyFileLimit_firstFilename)       ?? "Unknown"
        let reasonRaw  = defaults?.string(forKey: kEmptyFileLimit_reason)              ?? ""
        let reason     = EmptyFileLimitReason(rawValue: reasonRaw) ?? .quotaExceeded

        defaults?.set(0, forKey: kEmptyFileLimit_count)
        defaults?.removeObject(forKey: kEmptyFileLimit_firstFilename)
        defaults?.removeObject(forKey: kEmptyFileLimit_reason)
        defaults?.synchronize()

        return (count, filename, reason)
    }
}
