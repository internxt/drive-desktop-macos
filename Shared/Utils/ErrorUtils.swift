//
//  ErrorUtils.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 22/8/23.
//

import Foundation
import os.log
let sentryLogger = LogService.shared.createLogger(subsystem: .Errors, category: "Sentry")


struct ErrorUtils {
 
    
    static func fatal(_ message: String) -> Never {
        sentryLogger.error("FATAL: \(String(describing: message))")
        fatalError(message)
    }
    
    static func capture(_ message: String) -> Void {
        sentryLogger.info("Captured and reported error to Sentry: \(message)")
        
    }
    
}
