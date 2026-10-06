//
//  ProcessInfo.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import IOKit.pwr_mgt

public final class PowerAssertionManager {
    public static let shared = PowerAssertionManager()

    private let logger = LogService.shared.createLogger(subsystem: .XPCBackups, category: "PowerAssertionManager")
    private var assertionID: IOPMAssertionID = 0
    private var activityToken: NSObjectProtocol?
    private var activeOperations: Set<String> = []
    private let lock = NSLock()

    private init() {}

    /// Acquires a power assertion to prevent idle system sleep and App Nap while operations are running.
    /// Thread-safe and supports multiple callers by tracking active operation IDs.
    public func acquire(operation: String) {
        lock.lock()
        defer { lock.unlock() }

        let wasEmpty = activeOperations.isEmpty
        activeOperations.insert(operation)

        guard wasEmpty else {
            logger.info("⚡️ Power assertion retained for '\(operation)' (active operations: \(activeOperations.count))")
            return
        }

       
        if activityToken == nil {
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: [.userInitiated, .idleSystemSleepDisabled],
                reason: "Internxt Backup in progress"
            )
        }

        let reason = "Internxt Backup in progress" as CFString
        var newAssertionID: IOPMAssertionID = 0
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &newAssertionID
        )

        if success == kIOReturnSuccess {
            self.assertionID = newAssertionID
            logger.info("⚡️ Successfully acquired IOPMAssertion (ID: \(self.assertionID)) to prevent idle system sleep for '\(operation)'")
        } else {
            logger.error("❌ Failed to create IOPMAssertion: returnCode \(success)")
            self.assertionID = 0
        }
    }

    /// Releases the power assertion for the given operation.
    /// The system assertion is only released once ALL active operations have completed.
    public func release(operation: String) {
        lock.lock()
        defer { lock.unlock() }

        activeOperations.remove(operation)

        if activeOperations.isEmpty {
            releaseInternal()
        } else {
            logger.info("⚡️ Power assertion released for '\(operation)', still active for \(activeOperations.count) operation(s)")
        }
    }

   
    public func forceReleaseAll() {
        lock.lock()
        defer { lock.unlock() }

        activeOperations.removeAll()
        releaseInternal()
    }

    private func releaseInternal() {
        if assertionID != 0 {
            let result = IOPMAssertionRelease(assertionID)
            if result == kIOReturnSuccess {
                logger.info("⚡️ Successfully released IOPMAssertion (ID: \(self.assertionID))")
            } else {
                logger.error("❌ Failed to release IOPMAssertion: returnCode \(result)")
            }
            assertionID = 0
        }

        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
            logger.info("⚡️ Ended ProcessInfo activity")
        }
    }

    deinit {
        forceReleaseAll()
    }
}

extension ProcessInfo {
}
