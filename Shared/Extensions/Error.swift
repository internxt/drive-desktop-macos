//
//  Error.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 23/8/23.
//

import Foundation
import Sentry

extension Error {
    func reportToSentry() {
        sentryLogger.error("\(String(describing: self))")
        SentrySDK.capture(error: self)
    }
}
