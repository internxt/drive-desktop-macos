//
//  Error.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import Sentry
import InternxtSwiftCore

extension Error {
    func reportToSentry() {
        sentryLogger.error(self.getErrorDescription())
        SentrySDK.capture(error: self)
    }
    
    func getErrorDescription() -> String {
         if let apiClientError = self as? APIClientError {
             let responseBody = String(decoding: apiClientError.responseBody, as: UTF8.self)
             return "APIClientError \(apiClientError.statusCode) - \(responseBody)"
         }
         return self.localizedDescription
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
