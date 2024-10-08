//
//  ErrorUtils.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation
import Sentry
import os.log
let sentryLogger = LogService.shared.createLogger(subsystem: .Errors, category: "Sentry")


struct ErrorUtils {
 
    static func start() {
        let dsn = ConfigLoader().get().SENTRY_DSN
        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = false
            options.enableAppHangTracking = false
            options.tracesSampleRate = 0.5
            options.sampleRate = 0.5
        }
        
        
        sentryLogger.info("Sentry is ready")
    }
    
    static func fatal(_ message: String) -> Never {
        sentryLogger.error("FATAL: \(String(describing: message))")
        SentrySDK.capture(message: message)
        fatalError(message)
    }
    
    static func capture(_ message: String) -> Void {
        sentryLogger.info("Captured and reported error to Sentry: \(message)")
        SentrySDK.capture(message: message)
        
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
