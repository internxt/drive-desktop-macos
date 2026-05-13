//
//  FileSizeLimitNotifier.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 11/5/26.
//

import Foundation
import FileProvider

public let NOTIFICATION_FILE_SIZE_EXCEEDED = "com.internxt.drive.fileSizeExceeded"
private let kFileSizeExceeded_filename    = "FileSizeExceeded_filename"
private let kFileSizeExceeded_fileBytes   = "FileSizeExceeded_fileBytes"
private let kFileSizeExceeded_limitBytes  = "FileSizeExceeded_limitBytes"
private let kFileSizeExceeded_count       = "FileSizeExceeded_count"


private let _lock = NSLock()



public enum FileSizeLimitNotifier {
    
    
    public static func postExceeded(filename: String,
                                    fileBytes: Int64,
                                    limitBytes: Int64) {
        _lock.lock()
        defer { _lock.unlock() }
        
        let defaults = UserDefaults(suiteName: INTERNXT_GROUP_NAME)
        
        
        let previousCount = defaults?.integer(forKey: kFileSizeExceeded_count) ?? 0
        let newCount = previousCount + 1
        defaults?.set(newCount, forKey: kFileSizeExceeded_count)
        
        if previousCount == 0 {
            defaults?.set(filename,   forKey: kFileSizeExceeded_filename)
            defaults?.set(fileBytes,  forKey: kFileSizeExceeded_fileBytes)
            defaults?.set(limitBytes, forKey: kFileSizeExceeded_limitBytes)
        }
        
        defaults?.synchronize()
        
        
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(NOTIFICATION_FILE_SIZE_EXCEEDED),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )
    }
    
    
    public static func readAndResetBatch() -> (
        rejectedCount: Int,
        filename: String,
        fileBytes: Int64,
        limitBytes: Int64
    ) {
        let defaults = UserDefaults(suiteName: INTERNXT_GROUP_NAME)
        
        let count      = defaults?.integer(forKey: kFileSizeExceeded_count)              ?? 0
        let filename   = defaults?.string(forKey: kFileSizeExceeded_filename)             ?? "Unknown"
        let fileBytes  = defaults?.object(forKey: kFileSizeExceeded_fileBytes)  as? Int64 ?? 0
        let limitBytes = defaults?.object(forKey: kFileSizeExceeded_limitBytes) as? Int64 ?? 0
        
        defaults?.set(0,  forKey: kFileSizeExceeded_count)
        defaults?.removeObject(forKey: kFileSizeExceeded_filename)
        defaults?.synchronize()
        
        return (count, filename, fileBytes, limitBytes)
    }
}



public extension NSError {
    
    static func fileSizeExceededError() -> NSError {
        NSError(
            domain: "NSFileProviderErrorDomain",
            code: NSFileProviderError.cannotSynchronize.rawValue,
            userInfo: [
                NSLocalizedDescriptionKey: NSLocalizedString(
                    "file_size_exceeded_error",
                    value: "The file exceeds the maximum upload size allowed by your current plan.",
                    comment: "Error shown when a file is larger than the plan limit"
                )
            ]
        )
    }
}

