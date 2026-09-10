//
//  MailBridgeService.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import Foundation
import SwiftUI
import Security

enum MailBridgeViewState: Equatable {
    case locked
    case inactive
    case active
}

enum MailClient: String, CaseIterable, Identifiable {
    case appleMail = "Apple Mail"
    case outlook = "Outlook"
    case thunderbird = "Thunderbird"
    case other = "MAIL_BRIDGE_CLIENT_OTHER"

    var id: String { rawValue }

    var displayName: String {
        self == .other ? NSLocalizedString(rawValue, comment: "Generic mail client") : rawValue
    }

    var initial: String {
        switch self {
        case .appleMail: return "A"
        case .outlook: return "O"
        case .thunderbird: return "T"
        case .other: return "+"
        }
    }
}

enum ProtocolKind: String, Identifiable {
    case imap = "IMAP"
    case smtp = "SMTP"

    var id: String { rawValue }

    var captionKey: String {
        self == .imap ? "MAIL_BRIDGE_IMAP_CAPTION" : "MAIL_BRIDGE_SMTP_CAPTION"
    }

    var symbol: String {
        self == .imap ? "tray.and.arrow.down" : "tray.and.arrow.up"
    }
}

struct CredentialRow: Identifiable {
    let kind: ProtocolKind
    let labelKey: String
    let value: String
    var isSecret: Bool = false

    var id: String { "\(kind.rawValue).\(labelKey)" }
}

// TODO: Refactor this Model when wiring the client with the Bridge Daemon
struct MailboxCredentials {
    var host = "127.0.0.1"
    var imapPort = 1143
    var smtpPort = 1025
    var username = ""
    var password = ""
    var imapSecurity = "STARTTLS"
    var smtpSecurity = "SSL"

    /// 43 alphanumeric characters (~256 bits), e.g. `gowTRkFX2jJEqepXCCLJsH7LvxRd8NCE1sibSnNBrDQ`.
    static func generatePassword() -> String {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let limit = UInt8(256 - (256 % alphabet.count))
        var password = ""
        password.reserveCapacity(43)

        while password.count < 43 {
            var bytes = [UInt8](repeating: 0, count: 43)
            if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
                bytes = bytes.map { _ in UInt8.random(in: 0...255) }
            }
            for byte in bytes where byte < limit && password.count < 43 {
                password.append(alphabet[Int(byte) % alphabet.count])
            }
        }

        return password
    }

    func rows(for protocolKind: ProtocolKind) -> [CredentialRow] {
        let port = String(protocolKind == .imap ? imapPort : smtpPort)
        let security = protocolKind == .imap ? imapSecurity : smtpSecurity

        return [
            CredentialRow(kind: protocolKind, labelKey: "MAIL_BRIDGE_HOSTNAME", value: host),
            CredentialRow(kind: protocolKind, labelKey: "MAIL_BRIDGE_PORT", value: port),
            CredentialRow(kind: protocolKind, labelKey: "MAIL_BRIDGE_USERNAME", value: username),
            CredentialRow(kind: protocolKind, labelKey: "MAIL_BRIDGE_PASSWORD", value: password, isSecret: true),
            CredentialRow(kind: protocolKind, labelKey: "MAIL_BRIDGE_SECURITY", value: security)
        ]
    }

    func clipboardSummary() -> String {
        """
        IMAP  \(host):\(imapPort)  \(imapSecurity)
        SMTP  \(host):\(smtpPort)  \(smtpSecurity)
        Username  \(username)
        Password  \(password)
        """
    }
}

@MainActor
final class MailBridgeService: ObservableObject {

    private enum DefaultsKeys {
        static let activateAtLaunch = "mailBridge.activateAtLaunch"
        static let imapPort = "mailBridge.imapPort"
        static let smtpPort = "mailBridge.smtpPort"
    }

    private enum DefaultPorts {
        static let imap = 1143
        static let smtp = 1025
    }

    private static let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "MailBridge")

    private let defaults: UserDefaults
    private let config: ConfigLoader

    /// Also the username clients authenticate with — Bridge never asks for a second login.
    @Published var accountEmail: String = "" {
        didSet { credentials.username = accountEmail }
    }
    @Published var viewState: MailBridgeViewState = .locked
    @Published var activateAtLaunch: Bool {
        didSet { defaults.set(activateAtLaunch, forKey: DefaultsKeys.activateAtLaunch) }
    }
    @Published var imapPort: Int {
        didSet { defaults.set(imapPort, forKey: DefaultsKeys.imapPort) }
    }
    @Published var smtpPort: Int {
        didSet { defaults.set(smtpPort, forKey: DefaultsKeys.smtpPort) }
    }

    @Published var credentials = MailboxCredentials()

    @Published var syncedMessages: Int = 0
    @Published var totalMessages: Int = 0
    @Published var estimatedRemaining: String = ""

    init(defaults: UserDefaults = .standard, config: ConfigLoader = ConfigLoader()) {
        self.defaults = defaults
        self.config = config
        self.activateAtLaunch = defaults.bool(forKey: DefaultsKeys.activateAtLaunch)

        let storedImap = defaults.integer(forKey: DefaultsKeys.imapPort)
        let storedSmtp = defaults.integer(forKey: DefaultsKeys.smtpPort)
        self.imapPort = storedImap == 0 ? DefaultPorts.imap : storedImap
        self.smtpPort = storedSmtp == 0 ? DefaultPorts.smtp : storedSmtp

        self.credentials.imapPort = self.imapPort
        self.credentials.smtpPort = self.smtpPort
        self.credentials.username = accountEmail
        self.credentials.password = Self.loadOrCreatePassword(config: config)
    }

    /// The bridge password is generated once and then reused: the daemon has to
    /// authenticate clients with the same value the user copied into their mail app.
    private static func loadOrCreatePassword(config: ConfigLoader) -> String {
        if let stored = config.getMailBridgePassword(), !stored.isEmpty {
            return stored
        }

        let generated = MailboxCredentials.generatePassword()
        do {
            try config.setMailBridgePassword(password: generated)
        } catch {
            logger.error("Could not persist the Mail Bridge password: \(error)")
        }
        return generated
    }

    var progress: Double {
        guard totalMessages > 0 else { return 0 }
        return Double(syncedMessages) / Double(totalMessages)
    }

    var progressPercent: Int { Int((progress * 100).rounded()) }

    var endpointSummary: String {
        "\(accountEmail) · \(credentials.host) · IMAP \(imapPort) · SMTP \(smtpPort)"
    }

    var autostartNote: String {
        NSLocalizedString(
            activateAtLaunch ? "MAIL_BRIDGE_AUTOSTART_ON_NOTE" : "MAIL_BRIDGE_AUTOSTART_OFF_NOTE",
            comment: "Footer explaining whether Bridge starts on its own"
        )
    }

    var progressSummary: String {
        String(
            format: NSLocalizedString("MAIL_BRIDGE_DECRYPTING_%d_%@_%@", comment: "Mailbox decryption progress"),
            progressPercent,
            syncedMessages.formatted(),
            totalMessages.formatted()
        )
    }

    // MARK: - Actions

    func activate() {
        credentials.imapPort = imapPort
        credentials.smtpPort = smtpPort
        withAnimation(.easeOut(duration: 0.18)) { viewState = .active }
    }

    func deactivate() {
        withAnimation(.easeOut(duration: 0.18)) { viewState = .inactive }
    }

    func resync() {
        // TODO: Resync through the Bridge Daemon connection
    }

    func configureAutomatically(_ client: MailClient) {
        // TODO: Write the mail client profile for the given client
    }

    func applyPorts(imap: Int, smtp: Int) {
        imapPort = imap
        smtpPort = smtp
        credentials.imapPort = imap
        credentials.smtpPort = smtp
    }
}
