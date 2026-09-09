//
//  Error.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import FileProvider
import InternxtSwiftCore

extension Error {
    func reportToSentry() {
        sentryLogger.error(self.getErrorDescription())
    }
    
    func getErrorDescription() -> String {
        if let enrichedError = self as? EnrichedError {
            var parts = ["[\(enrichedError.code.rawValue)]", "Step: \(enrichedError.step.rawValue)"]
            if !enrichedError.context.isEmpty {
                let contextStr = enrichedError.context.map { "\($0.key): \($0.value)" }.joined(separator: ", ")
                parts.append("| \(contextStr)")
            }
            if let cause = enrichedError.cause {
                parts.append("| Cause: \(cause.getErrorDescription())")
            }
            return parts.joined(separator: " ")
        }
        
        if let apiClientError = self as? APIClientError {
            let parts = [
                "APIClientError \(apiClientError.statusCode)",
                apiClientError.message,
                apiClientError.responseBody.isEmpty ? nil : String(decoding: apiClientError.responseBody, as: UTF8.self)
            ].compactMap { $0 }
            
            return parts.joined(separator: " | ")
        }
        
        if let uploadError = self as? UploadError {
            switch uploadError {
            case .InvalidIndex:
                return "UploadError: InvalidIndex"
            case .CannotGenerateFileHash:
                return "UploadError: CannotGenerateFileHash"
            case .FailedToFinishUpload:
                return "UploadError: FailedToFinishUpload"
            case .MissingUploadUrl:
                return "UploadError: MissingUploadUrl"
            case .UploadNotSuccessful:
                return "UploadError: UploadNotSuccessful"
            case .UploadedSizeNotMatching:
                return "UploadError: UploadedSizeNotMatching"
            case .MissingEtag:
                return "UploadError: MissingEtag"
            case .MissingChunk:
                return "UploadError: MissingChunk"
            case .PartUploadFailed(let partIndex, let innerError):
                return "UploadError: PartUploadFailed (part \(partIndex)) | error: \(innerError.getErrorDescription())"
            }
        }
        
        return self.localizedDescription
    }
    
    func checkUnauthorizedError() {
        if let apiClientError = self as? APIClientError, apiClientError.statusCode == 401 {
            DispatchQueue.main.async {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    NotificationCenter.default.post(name: .userDidLogout, object: nil)
                }
            }
        }
    }

    var isStorageFull: Bool {
        // Case 1: Direct APIClientError
        if let apiError = self as? APIClientError, apiError.statusCode == 420 { return true }
        
        // Case 2: EnrichedError wrapping APIClientError (single upload < 100MB)
        if let enriched = self as? EnrichedError,
            let apiError = enriched.cause as? APIClientError,
            apiError.statusCode == 420 { return true }
        
        // Case 3: EnrichedError wrapping UploadError.PartUploadFailed (multipart >= 100MB)
        if let enriched = self as? EnrichedError,
            let partFailed = enriched.cause as? UploadError,
            case .PartUploadFailed(_, let innerError) = partFailed,
            let apiError = innerError as? APIClientError,
            apiError.statusCode == 420 { return true }
        
        // Case 4: Direct UploadError.PartUploadFailed
        if let partFailed = self as? UploadError,
            case .PartUploadFailed(_, let innerError) = partFailed,
            let apiError = innerError as? APIClientError,
            apiError.statusCode == 420 { return true }
        
        return false
    }

    func toFileProviderError() -> NSError {
        if self.isStorageFull {
            syncExtensionLogger.error("❌ Cannot synchronize file: destination storage is full (420)")
            DistributedNotificationCenter.default().postNotificationName(
                .storageFull,
                object: nil,
                userInfo: nil,
                deliverImmediately: true
            )
            return NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue)
        } else if let apiClientError = self as? APIClientError, apiClientError.statusCode == 402 {
            syncExtensionLogger.error("❌ Cannot synchronize file due to payment/quota issue (402)")
            return NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.cannotSynchronize.rawValue)
        } else {
            return NSError(domain: NSFileProviderErrorDomain, code: NSFileProviderError.serverUnreachable.rawValue)
        }
    }

    func getUserFriendlyDescription() -> String {
        return ErrorFormatter.userFriendlyDescription(from: self.getErrorDescription()) ?? NSLocalizedString("ISSUE_ERROR_NETWORK", comment: "")
    }
}

public struct ErrorFormatter {
    public static func userFriendlyDescription(from message: String?) -> String? {
        guard let message = message, !message.isEmpty else {
            return nil
        }

        let lower = message.lowercased()

        // 1. Storage Full (420)
        if message.contains("420") || lower.contains("storage is full") || lower.contains("storage full") {
            return NSLocalizedString("ISSUE_ERROR_STORAGE_FULL", comment: "")
        }

        // 2. Authentication / Session (401)
        if message.contains("401") || lower.contains("unauthorized") || lower.contains("session expired") {
            return NSLocalizedString("ISSUE_ERROR_SESSION_EXPIRED", comment: "")
        }

        // 3. Payment / Plan limit (402)
        if message.contains("402") || lower.contains("payment required") {
            return NSLocalizedString("ISSUE_ERROR_PLAN_LIMIT", comment: "")
        }

        // 4. Not Found (404)
        if message.contains("404") || lower.contains("not found") {
            return NSLocalizedString("ISSUE_ERROR_NOT_FOUND", comment: "")
        }

        // 5. Conflict / Exists (409)
        if message.contains("409") || lower.contains("conflict") || lower.contains("already exists") {
            return NSLocalizedString("ISSUE_ERROR_ALREADY_EXISTS", comment: "")
        }

        // 6. Server Errors (500-599)
        if message.contains("500") || message.contains("502") || message.contains("503") || message.contains("504") || lower.contains("server error") {
            return NSLocalizedString("ISSUE_ERROR_SERVER", comment: "")
        }

        // 7. Enriched Error Codes
        // Upload
        if message.contains("UPL-001") {
            return NSLocalizedString("ISSUE_ERROR_NETWORK", comment: "")
        }
        if message.contains("UPL-002") {
            return NSLocalizedString("ISSUE_ERROR_TIMEOUT", comment: "")
        }
        if message.contains("UPL-003") || message.contains("UPL-004") {
            return NSLocalizedString("ISSUE_ERROR_GENERIC_UPLOAD", comment: "")
        }
        if message.contains("UPL-005") || message.contains("ENC-") {
            return NSLocalizedString("ISSUE_ERROR_ENCRYPTION", comment: "")
        }
        if message.contains("UPL-006") || lower.contains("size mismatch") {
            return NSLocalizedString("ISSUE_ERROR_SIZE_MISMATCH", comment: "")
        }
        if message.contains("UPL-") {
            return NSLocalizedString("ISSUE_ERROR_GENERIC_UPLOAD", comment: "")
        }

        // Download
        if message.contains("DWN-002") || message.contains("DEC-") {
            return NSLocalizedString("ISSUE_ERROR_DECRYPTION", comment: "")
        }
        if message.contains("DWN-003") || lower.contains("hash mismatch") {
            return NSLocalizedString("ISSUE_ERROR_INTEGRITY", comment: "")
        }
        if message.contains("DWN-") {
            return NSLocalizedString("ISSUE_ERROR_GENERIC_DOWNLOAD", comment: "")
        }

        // Network
        if message.contains("NET-001") || lower.contains("timed out") || message.contains("-1001") {
            return NSLocalizedString("ISSUE_ERROR_TIMEOUT", comment: "")
        }
        if message.contains("NET-002") || message.contains("-1009") || lower.contains("not connected to the internet") || lower.contains("offline") {
            return NSLocalizedString("ISSUE_ERROR_NO_INTERNET", comment: "")
        }
        if message.contains("NET-003") || message.contains("-1005") || lower.contains("connection was lost") {
            return NSLocalizedString("ISSUE_ERROR_CONNECTION_LOST", comment: "")
        }
        if message.contains("NET-004") || message.contains("-1004") || lower.contains("cannot connect") || lower.contains("websocket") {
            return NSLocalizedString("ISSUE_ERROR_NETWORK", comment: "")
        }

        // Catch-all for step messages
        if message.contains("Step: upload") {
            return NSLocalizedString("ISSUE_ERROR_GENERIC_UPLOAD", comment: "")
        }
        if message.contains("Step: download") {
            return NSLocalizedString("ISSUE_ERROR_GENERIC_DOWNLOAD", comment: "")
        }
        if message.contains("APIClientError") {
            return NSLocalizedString("ISSUE_ERROR_SERVER", comment: "")
        }

        // If it's a short, user-friendly message already (no technical brackets or pipes)
        if !message.contains("[") && !message.contains("|") && !message.contains("Error:") && message.count <= 60 {
            return message
        }

        return NSLocalizedString("ISSUE_ERROR_NETWORK", comment: "")
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
    static let storageFull = Notification.Name("com.internxt.drive.storageFull")
}
