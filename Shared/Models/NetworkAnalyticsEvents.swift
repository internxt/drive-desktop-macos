//
//  Analytics.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/10/23.
//

import Foundation
enum NetworkAnalyticsEvent: String {
    case UPLOAD_STARTED = "Upload Started"
    case UPLOAD_COMPLETED = "Upload Completed"
    case UPLOAD_ERROR = "Upload Error"
    case DOWNLOAD_STARTED = "Download Started"
    case DOWNLOAD_COMPLETED = "Download Completed"
    case DOWNLOAD_ERROR = "Download Error"
    case SUCCESS_BACKUP = "Success Backup"
    case FAILURE_BACKUP = "Failure Backup"
}

func getBandwidthUsage(fileSizeBytes: Int64, durationMs: Int) -> Int {
    /**
     * TODO: Define a better way to gather bandwidth usage, MetricKit is not enough
     * and dividing size/duration throws very random values
     **/
    return 0
}

protocol DownloadAnalyticsEventPayload {
    var eventName: NetworkAnalyticsEvent { get set }
    var fileName: String { get set }
    var fileExtension: String { get set }
    var fileSize: Int64 { get set }
    var fileUuid: String { get set }
    var fileId: String {get set}
    var parentFolderId: Int { get set }
    
    func getProperties() -> [String: Any]
    
}

protocol UploadAnalyticsEventPayload {
    var eventName: NetworkAnalyticsEvent { get set }
    var fileName: String { get set }
    var fileExtension: String { get set }
    var fileSize: Int64 { get set }
    var fileUploadId: String {get set}
    var processIdentifier: String {get set}
    var parentFolderId: Int { get set }
    
    func getProperties() -> [String: Any]
    
}

protocol BackupEventPayload {
    var eventName: NetworkAnalyticsEvent { get set }
    var foldersToBackup: Int {get set}
    func getProperties() -> [String: Any]

}

extension UploadAnalyticsEventPayload {
    func getAllProperties() -> [String: Any] {
        
        return [
            "process_identifier": self.processIdentifier,
            "file_name": self.fileName,
            "file_extension": self.fileExtension,
            "file_size": self.fileSize,
            "file_upload_id": self.fileUploadId,
            "parent_folder_id": self.parentFolderId,
            "is_multiple": 0,
            "is_brave": false
        ].merging(self.getProperties()){ (_, new) in new }
    }
}

extension DownloadAnalyticsEventPayload {
    func getMergedProperties() -> [String: Any] {
        
        return [
            "process_identifier": self.fileUuid,
            "file_id": self.fileId,
            "file_name": self.fileName,
            "file_extension": self.fileExtension,
            "file_size": self.fileSize,
            "parent_folder_id": self.parentFolderId,
            "is_multiple": 0,
        ].merging(self.getProperties()){ (_, new) in new }
    }
}

extension BackupEventPayload {
    func getMergedProperties() -> [String: Any] {

        return [
            "folders_number": self.foldersToBackup,
        ].merging(self.getProperties()){ (_, new) in new }
    }
}

// Upload events
struct UploadStartedEvent: UploadAnalyticsEventPayload {
    
    
    var eventName = NetworkAnalyticsEvent.UPLOAD_STARTED
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUploadId: String
    var processIdentifier: String
    var parentFolderId: Int
    
    internal func getProperties() -> [String : Any] {
        return [:]
    }
}

struct UploadCompletedEvent: UploadAnalyticsEventPayload {
    var eventName = NetworkAnalyticsEvent.UPLOAD_COMPLETED
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUploadId: String
    var processIdentifier: String
    var parentFolderId: Int
    var elapsedTimeMs: Double
    
    internal func getProperties() -> [String : Any] {
        return [
            "elapsedTimeMs": self.elapsedTimeMs,
            "bandwidth": getBandwidthUsage(fileSizeBytes: self.fileSize, durationMs: Int(self.elapsedTimeMs))
        ]
    }
    
}


struct UploadErrorEvent: UploadAnalyticsEventPayload {
    
    var eventName = NetworkAnalyticsEvent.UPLOAD_ERROR
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUploadId: String
    var processIdentifier: String
    var parentFolderId: Int
    var error: any Error
    
    internal func getProperties() -> [String : Any] {
        return [
            "error_message_user": self.error.localizedDescription,
            "error_message": self.error.localizedDescription,
            "stack_trace": "NOT_AVAILABLE_DESKTOP_MACOS"
        ]
    }
}


struct DownloadStartedEvent: DownloadAnalyticsEventPayload {
    var eventName = NetworkAnalyticsEvent.DOWNLOAD_STARTED
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUuid: String
    var fileId: String
    var parentFolderId: Int
    
    internal func getProperties() -> [String : Any] {
        return [:]
    }
}

struct DownloadCompletedEvent: DownloadAnalyticsEventPayload {
    var eventName = NetworkAnalyticsEvent.DOWNLOAD_COMPLETED
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUuid: String
    var fileId: String
    var parentFolderId: Int
    var elapsedTimeMs: Double
    
    internal func getProperties() -> [String : Any] {
        return [
            "elapsedTimeMs": self.elapsedTimeMs,
            "bandwidth": getBandwidthUsage(fileSizeBytes: self.fileSize, durationMs: Int(self.elapsedTimeMs))
        ]
    }
}

   
struct DownloadErrorEvent: DownloadAnalyticsEventPayload {
    
    var eventName = NetworkAnalyticsEvent.DOWNLOAD_ERROR
    var fileName: String
    var fileExtension: String
    var fileSize: Int64
    var fileUuid: String
    var fileId: String
    var parentFolderId: Int
    var error: any Error
    
    internal func getProperties() -> [String : Any] {
        return [
            "error_message_user": self.error.localizedDescription,
            "error_message": self.error.localizedDescription,
            "stack_trace": "NOT_AVAILABLE_DESKTOP_MACOS"
        ]
    }
}

struct SuccessBackupEvent: BackupEventPayload {
    var eventName = NetworkAnalyticsEvent.SUCCESS_BACKUP
    var foldersToBackup: Int
    internal func getProperties() -> [String : Any] {
        return [:]
    }
}

struct FailureBackupEvent: BackupEventPayload{
    var eventName = NetworkAnalyticsEvent.FAILURE_BACKUP
    var foldersToBackup: Int
    var error: String

    internal func getProperties() -> [String : Any] {
        return [
            "error_message_user": self.error,
            "error_message": self.error,
            "stack_trace": "NOT_AVAILABLE_DESKTOP_MACOS"
        ]
    }
}

