//
//  Error.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import InternxtSwiftCore
import AppKit

extension Error {
    func reportToSentry() {
        sentryLogger.error(self.getErrorDescription())
    }
    
    func getErrorDescription() -> String {
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
}

extension NSAlert {
    static func showStorageFullAlert() {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("ALERT_STORAGE_TITLE", comment: "")
        alert.informativeText = NSLocalizedString("ALERT_STORAGE_SUBTITLE", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("ALERT_STORAGE_BUTTON_TITLE", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("COMMON_CANCEL", comment: ""))
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            URLDictionary.UPGRADE_PLAN.open()
        }
    }
}

extension Notification.Name {
    static let userDidLogout = Notification.Name("userDidLogout")
}
