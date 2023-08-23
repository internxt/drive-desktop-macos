//
//  ErrorUtils.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation
import Sentry
import os.log
let sentryLogger = Logger(subsystem: "com.internxt", category: "Sentry")


struct ErrorUtils {
 
    static func start() {
        SentrySDK.start { options in
            options.dsn = ConfigLoader().get().SENTRY_DSN
            options.debug = false
            options.tracesSampleRate = 1.0
        }
    }
    
    static func fatal(_ message: String) -> Never {
        sentryLogger.error("FATAL: \(String(describing: message))")
        SentrySDK.capture(message: message)
        fatalError(message)
    }
    
    static func identify(email: String, uuid: String) {
        let user = User()
        user.email = email
        user.userId = uuid
        SentrySDK.setUser(user)
    }
    
    static func clean() {
        SentrySDK.setUser(nil)
    }
}
