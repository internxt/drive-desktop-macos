//
//  UpdateEnforcementManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 3/11/26.
//

import Foundation
import Combine

extension Notification.Name {
    public static let updateRequiredNotification = Notification.Name("com.internxt.drive.updateRequiredNotification")
}

public class UpdateEnforcementManager: ObservableObject {
    public static let shared = UpdateEnforcementManager()

    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "UpdateEnforcement")
    private let suiteName = INTERNXT_GROUP_NAME

    @Published public private(set) var isBlocked: Bool = false

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: suiteName)
    }

    private init() {
        self.isBlocked = sharedDefaults?.bool(forKey: UPDATE_MANDATORY_KEY) ?? false
        if self.isBlocked {
            logger.warning("App initialized with mandatory update enforcement active.")
        }
    }


    @MainActor
    public func triggerEnforcement(reason: String) {
        logger.warning("🚨 Triggering mandatory update enforcement: \(reason)")
        self.isBlocked = true
        sharedDefaults?.set(true, forKey: UPDATE_MANDATORY_KEY)

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(NOTIFICATION_UPDATE_REQUIRED),
            object: nil,
            userInfo: ["reason": reason],
            deliverImmediately: true
        )

        NotificationCenter.default.post(
            name: .updateRequiredNotification,
            object: nil,
            userInfo: ["reason": reason]
        )
    }

    @MainActor
    public func clearEnforcement() {
        guard isBlocked else { return }
        logger.info("✅ Clearing mandatory update enforcement.")
        self.isBlocked = false
        sharedDefaults?.removeObject(forKey: UPDATE_MANDATORY_KEY)
    }

    @MainActor
    public func evaluateVersionPolicy(minimumSupportedVersionString: String) {
        guard let minimumVersion = AppVersion.parse(minimumSupportedVersionString),
              let currentVersion = AppVersion.current() else {
            logger.error("Failed to parse version strings: min=\(minimumSupportedVersionString)")
            return
        }

        if AppVersion.isDeprecated(current: currentVersion, minimumSupported: minimumVersion) {
            triggerEnforcement(reason: "Current version \(currentVersion) is below minimum supported \(minimumVersion)")
        } else if isBlocked {
            clearEnforcement()
        }
    }
}
