//
//  MailProfile.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 21/09/2026.
//

import Foundation
import AppKit
import Security

/// Sets Internxt Mail up in Apple Mail: trusts Bridge's certificate, then hands the
/// system a configuration profile describing the account.
///
/// The profile exists because Bridge cannot listen where Mail assumes — 143, 465, 587
/// and 993 are below 1024, and only root may bind those — so the ports have to be
/// stated outright rather than left for the user to correct by hand.
///
/// The certificate is a separate job from the profile even though a profile can carry
/// one, because macOS only trusts a root a profile brings when an MDM pushed that
/// profile. Installed by hand it leaves the certificate present but unanchored, which
/// Mail reports as not being able to verify the identity of the server.
enum MailProfile {
    static let identifier = "com.internxt.drive.mailbridge"
    static let certificateLabel = "Internxt Mail Bridge Profile"

    enum MailProfileError: Error, LocalizedError {
        case noCertificate
        case unreadableCertificate
        case notTrusted(OSStatus)

        var errorDescription: String? {
            switch self {
            case .noCertificate:
                return "Mail Bridge is running without encryption, so Apple Mail would refuse the account"
            case .unreadableCertificate:
                return "Mail Bridge sent a certificate this Mac cannot read"
            case .notTrusted(let status) where status == errSecUserCanceled || status == errAuthorizationCanceled:
                return "Apple Mail cannot be set up until this Mac is allowed to trust the Mail Bridge certificate"
            case .notTrusted(let status):
                return "This Mac would not trust the Mail Bridge certificate (error \(status))"
            }
        }
    }

    @MainActor
    static func setUpAppleMail(_ account: Account) async throws {
        guard let certificate = account.certificate else { throw MailProfileError.noCertificate }

        try await Task.detached { try trustCertificate(certificate) }.value

        let url = try writeProfile(for: account)
        NSWorkspace.shared.open(url)
        openProfilesSettings()
    }

    /// Anchors the certificate here rather than shipping it inside the profile as a
    /// `com.apple.security.root` payload, which looks like the obvious simplification
    /// and does not work: macOS only trusts a root a profile carries when an MDM pushed
    /// that profile. Installed by hand it leaves the certificate present but unanchored,
    /// and Mail reports it as not being able to verify the identity of the server.
    private static func trustCertificate(_ der: Data) throws {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw MailProfileError.unreadableCertificate
        }

        let stored = SecItemAdd([
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate,
            kSecAttrLabel as String: certificateLabel
        ] as CFDictionary, nil)
        guard stored == errSecSuccess || stored == errSecDuplicateItem else {
            throw MailProfileError.notTrusted(stored)
        }

        guard !isCertificateAlreadyTrusted(certificate) else { return }

        let anchored = SecTrustSettingsSetTrustSettings(certificate, .user, [
            [
                kSecTrustSettingsPolicy as String: SecPolicyCreateSSL(true, nil),
                kSecTrustSettingsResult as String: SecTrustSettingsResult.trustRoot.rawValue
            ]
        ] as CFTypeRef)
        guard anchored == errSecSuccess else {
            throw MailProfileError.notTrusted(anchored)
        }
    }

    static func refreshTrustIfNeeded(_ der: Data) async {
        let stale = existingCertificates()
        guard !stale.isEmpty else { return }
        guard !stale.contains(where: { (SecCertificateCopyData($0) as Data) == der }) else { return }

        await Task.detached {
            stale.forEach(forgetCertificate)
            try? trustCertificate(der)
        }.value
    }
    
    private static func forgetCertificate(_ certificate: SecCertificate) {
        SecTrustSettingsRemoveTrustSettings(certificate, .user)
        SecItemDelete([
            kSecClass as String: kSecClassCertificate,
            kSecValueRef as String: certificate
        ] as CFDictionary)
    }

    private static func existingCertificates() -> [SecCertificate] {
        var found: CFTypeRef?
        let matched = SecItemCopyMatching([
            kSecClass as String: kSecClassCertificate,
            kSecAttrLabel as String: certificateLabel,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true
        ] as CFDictionary, &found)
        guard matched == errSecSuccess, let certificates = found as? [SecCertificate] else { return [] }
        return certificates
    }

    static func removeAppleMailSetup() {
        DispatchQueue.global(qos: .utility).async {
            untrustCertificate()
            removeProfile()
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private static func isCertificateAlreadyTrusted(_ certificate: SecCertificate) -> Bool {
        var settings: CFArray?
        return SecTrustSettingsCopyTrustSettings(certificate, .user, &settings) == errSecSuccess
    }

    private static func untrustCertificate() {
        existingCertificates().forEach(forgetCertificate)
    }

    private static func removeProfile() {
        let profiles = Process()
        profiles.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        profiles.arguments = ["remove", "-identifier", identifier]

        try? profiles.run()
        profiles.waitUntilExit()
    }

    struct Account {
        let address: String
        let password: String
        let imapPort: Int
        let smtpPort: Int
        let certificate: Data?
    }

    // MARK: - Writing it out

    static var fileURL: URL {
        MailBridgeProcess.stateDirectory.appendingPathComponent("InternxtMail.mobileconfig")
    }

    private static func writeProfile(for account: Account) throws -> URL {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        let profile = try encoder.encode(Profile(account: account))

        let url = fileURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try profile.write(to: url, options: .atomic)

        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)

        return url
    }

    private static func openProfilesSettings() {
        guard let pane = URL(string: "x-apple.systempreferences:com.apple.preferences.configurationprofiles") else {
            return
        }
        NSWorkspace.shared.open(pane)
    }
}

// MARK: - The profile itself

private extension MailProfile {

    struct Profile: Encodable {
        let payloadType = "Configuration"
        let payloadVersion = 1
        let payloadIdentifier = MailProfile.identifier
        let payloadUUID = UUID().uuidString
        let payloadDisplayName = "Internxt Mail"
        let payloadOrganization = "Internxt"
        let payloadDescription = "Sets up Internxt Mail in Apple Mail through Mail Bridge, which runs on this Mac."
        let payloadScope = "User"
        let payloadRemovalDisallowed = false
        let payloadContent: [MailPayload]

        init(account: Account) {
            payloadContent = [MailPayload(account: account)]
        }

        enum CodingKeys: String, CodingKey {
            case payloadType = "PayloadType"
            case payloadVersion = "PayloadVersion"
            case payloadIdentifier = "PayloadIdentifier"
            case payloadUUID = "PayloadUUID"
            case payloadDisplayName = "PayloadDisplayName"
            case payloadOrganization = "PayloadOrganization"
            case payloadDescription = "PayloadDescription"
            case payloadScope = "PayloadScope"
            case payloadRemovalDisallowed = "PayloadRemovalDisallowed"
            case payloadContent = "PayloadContent"
        }
    }

    struct MailPayload: Encodable {
        let payloadType = "com.apple.mail.managed"
        let payloadVersion = 1
        let payloadIdentifier = "\(MailProfile.identifier).account"
        let payloadUUID = UUID().uuidString
        let payloadDisplayName = "Internxt Mail account"

        let accountDescription = "Internxt Mail"
        let accountType = "EmailTypeIMAP"
        let accountName: String
        let address: String

        let incomingHost = MailboxCredentials().host
        let incomingPort: Int
        let incomingUseSSL = true
        let incomingAuthentication = "EmailAuthPassword"
        let incomingUsername: String
        let incomingPassword: String

        let outgoingHost = MailboxCredentials().host
        let outgoingPort: Int
        let outgoingUseSSL = true
        let outgoingAuthentication = "EmailAuthPassword"
        let outgoingUsername: String
        let outgoingPasswordSameAsIncoming = true

        init(account: Account) {
            accountName = account.address
            address = account.address
            incomingPort = account.imapPort
            incomingUsername = account.address
            incomingPassword = account.password
            outgoingPort = account.smtpPort
            outgoingUsername = account.address
        }

        enum CodingKeys: String, CodingKey {
            case payloadType = "PayloadType"
            case payloadVersion = "PayloadVersion"
            case payloadIdentifier = "PayloadIdentifier"
            case payloadUUID = "PayloadUUID"
            case payloadDisplayName = "PayloadDisplayName"

            case accountDescription = "EmailAccountDescription"
            case accountType = "EmailAccountType"
            case accountName = "EmailAccountName"
            case address = "EmailAddress"

            case incomingHost = "IncomingMailServerHostName"
            case incomingPort = "IncomingMailServerPortNumber"
            case incomingUseSSL = "IncomingMailServerUseSSL"
            case incomingAuthentication = "IncomingMailServerAuthentication"
            case incomingUsername = "IncomingMailServerUsername"
            case incomingPassword = "IncomingPassword"

            case outgoingHost = "OutgoingMailServerHostName"
            case outgoingPort = "OutgoingMailServerPortNumber"
            case outgoingUseSSL = "OutgoingMailServerUseSSL"
            case outgoingAuthentication = "OutgoingMailServerAuthentication"
            case outgoingUsername = "OutgoingMailServerUsername"
            case outgoingPasswordSameAsIncoming = "OutgoingPasswordSameAsIncomingPassword"
        }
    }
}
