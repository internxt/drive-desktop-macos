//
//  Analytics.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/10/23.
//

import Foundation
enum AnalyticsEvent: String {
    case SEND_FEEDBACK = "Feedback Sent"
    case UPLOAD_STARTED = "Upload Started"
    case UPLOAD_COMPLETED = "Upload Completed"
    case UPLOAD_ERROR = "Upload Error"
}

protocol AnalyticsEventPayload {
    var eventName: AnalyticsEvent { get set }
    func toPayload() -> [String: Any]
}

// Upload events

struct UploadStartedEvent: AnalyticsEventPayload {
    var eventName: AnalyticsEvent = AnalyticsEvent.UPLOAD_STARTED
    
    public let fileName: String
    public let fileExtension: String
    public let fileSize: Int64
    public let fileUuid: String
    
    func toPayload() -> [String : Any] {
        return [
            "file_name": self.fileName,
            "file_extension": self.fileExtension,
            "file_size": self.fileSize,
            "file_upload_id": self.fileUuid,
            // Unable to calculate for now
            "bandwidth": 0,
            // Unable to calculate for now
            "band_utilization": 0,
            "is_multiple": 0,
        ]
    }
    
}

struct UploadCompletedEvent: AnalyticsEventPayload {
    var eventName: AnalyticsEvent = AnalyticsEvent.UPLOAD_COMPLETED
    
    public let fileName: String
    public let fileExtension: String
    public let fileSize: Int64
    public let fileUuid: String
    public let elapsedTimeMs: Double
    
    func toPayload() -> [String : Any] {
        return [
            "file_upload_id": self.fileUuid,
            "file_name": self.fileName,
            "file_extension": self.fileExtension,
            "file_size": self.fileSize,
            // Unable to calculate for now
            "bandwidth": 0,
            // Unable to calculate for now
            "band_utilization": 0,
            "is_multiple": 0,
            "elapsedTimeMs": self.elapsedTimeMs
        ]
    }
    
}

struct UploadErrorEvent: AnalyticsEventPayload {
    var eventName: AnalyticsEvent = AnalyticsEvent.UPLOAD_ERROR
    
    public let fileName: String
    public let fileExtension: String
    public let fileSize: Int64
    public let fileUuid: String
    public let error: any Error
    
    func toPayload() -> [String : Any] {
        return [
            "file_upload_id": self.fileUuid,
            "file_name": self.fileName,
            "file_extension": self.fileExtension,
            "file_size": self.fileSize,
            // Unable to calculate for now
            "bandwidth": 0,
            // Unable to calculate for now
            "band_utilization": 0,
            "is_multiple": 0,
            "error_message": error.localizedDescription,
            "error_message_user":  error.localizedDescription,
            "stack_trace": "NO_STACKTRACE",
        ]
    }
    
}

   

