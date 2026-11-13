//
//  UpdateEnforcementManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 3/11/26.
//

import Foundation
import Combine
import InternxtSwiftCore

extension Notification.Name {
    public static let updateRequiredNotification = Notification.Name("com.internxt.drive.updateRequiredNotification")
    public static let updateRequiredClearedNotification = Notification.Name("com.internxt.drive.updateRequiredClearedNotification")
}

public class UpdateEnforcementManager: ObservableObject {
    public static let shared = UpdateEnforcementManager()

    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "UpdateEnforcement")
    private let suiteName = INTERNXT_GROUP_NAME
    private let blockedVersionKey = "UPDATE_MANDATORY_VERSION"

    @Published public private(set) var isBlocked: Bool = false
    @Published public private(set) var isDeprecated: Bool = false
    @Published public private(set) var sunsetAt: String? = nil
    @Published public private(set) var recommendedVersion: String? = nil
    @Published public private(set) var compatibilityStatus: ClientCompatibilityStatus = .upToDate

    private var periodicCheckTask: Task<Void, Never>? = nil

    private var sharedDefaults: UserDefaults? {
        return UserDefaults(suiteName: suiteName)
    }

    public var formattedSunsetDate: String? {
        guard let sunsetAt = sunsetAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: sunsetAt)
        if date == nil {
            let fallbackFormatter = ISO8601DateFormatter()
            date = fallbackFormatter.date(from: sunsetAt)
        }
        guard let validDate = date else { return sunsetAt }
        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium
        displayFormatter.timeStyle = .none
        return displayFormatter.string(from: validDate)
    }

    private init() {
        let currentVersion = getVersion()
        let blockedVersion = sharedDefaults?.string(forKey: blockedVersionKey)
        if let blockedVersion = blockedVersion, blockedVersion == currentVersion {
            self.isBlocked = sharedDefaults?.bool(forKey: UPDATE_MANDATORY_KEY) ?? false
        } else {
            self.isBlocked = false
            sharedDefaults?.removeObject(forKey: UPDATE_MANDATORY_KEY)
            sharedDefaults?.removeObject(forKey: blockedVersionKey)
        }
        if self.isBlocked {
            logger.warning("App initialized with mandatory update enforcement active for version \(currentVersion).")
        }
    }


    @MainActor
    public func triggerEnforcement(reason: String) {
        guard !isBlocked else {
            logger.info("ℹ️ Mandatory update enforcement already active, bringing window to front.")
            NotificationCenter.default.post(
                name: .updateRequiredNotification,
                object: nil,
                userInfo: ["reason": reason]
            )
            return
        }

        logger.warning("🚨 Triggering mandatory update enforcement: \(reason)")
        self.isBlocked = true
        sharedDefaults?.set(true, forKey: UPDATE_MANDATORY_KEY)
        sharedDefaults?.set(getVersion(), forKey: blockedVersionKey)

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
        sharedDefaults?.removeObject(forKey: blockedVersionKey)

        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(NOTIFICATION_UPDATE_REQUIRED_CLEARED),
            object: nil,
            userInfo: nil,
            deliverImmediately: true
        )

        NotificationCenter.default.post(
            name: .updateRequiredClearedNotification,
            object: nil
        )
    }

    @MainActor
    public func checkCompatibility() async {
        do {
            let compatibility = try await APIFactory.DriveNew.getClientCompatibility()
            logger.info("Compatibility check: status=\(compatibility.status.rawValue), sunsetAt=\(compatibility.sunsetAt ?? "none")")
            self.handleCompatibilityResult(compatibility)
        } catch {
            logger.warning("Compatibility check failed (not blocking client): \(error.localizedDescription)")
           
        }
    }

    @MainActor
    private func handleCompatibilityResult(_ result: ClientCompatibilityResponse) {
        self.compatibilityStatus = result.status
        self.recommendedVersion = result.recommendedVersion
        self.sunsetAt = result.sunsetAt

        switch result.status {
        case .unsupported:
            self.isDeprecated = false
            self.triggerEnforcement(reason: "Backend compatibility endpoint returned unsupported")

        case .deprecated:
            self.isDeprecated = true
            if self.isBlocked {
                self.clearEnforcement()
            }
            logger.warning("Version is deprecated with sunsetAt: \(result.sunsetAt ?? "none")")

        case .upToDate, .updateRecommended:
            self.isDeprecated = false
            if self.isBlocked {
                self.clearEnforcement()
            }
        }
    }

    public func startPeriodicCompatibilityCheck(interval: TimeInterval = 3600) {
        periodicCheckTask?.cancel()
        periodicCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.checkCompatibility()
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    public func stopPeriodicCompatibilityCheck() {
        periodicCheckTask?.cancel()
        periodicCheckTask = nil
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
