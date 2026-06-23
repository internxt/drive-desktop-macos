//
//  Error.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
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
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
    static let storageFull = Notification.Name("com.internxt.drive.storageFull")
}
