//
//  MailBridgeService.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import Foundation
import SwiftUI
import Security
import InternxtSwiftCore

enum MailBridgeViewState: Equatable {
    case locked
    case unlocked(Unlocked)

    enum Unlocked: Equatable {
        case identitySetup
        case inactive
        case active
        case failed
    }

    var isActive: Bool { self == .unlocked(.active) }
}

struct MailAccountIdentity {
    let address: String
    let publicKey: String
    let privateKey: [UInt8]
}

enum MailBridgeSyncState: Equatable {
    case upToDate
    case syncing(downloaded: Int, total: Int, percent: Int)
    case interrupted(downloaded: Int, total: Int)
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

struct MailboxCredentials {
    var host = "127.0.0.1"
    var imapPort = 1143
    var smtpPort = 1025
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

    func rows(for protocolKind: ProtocolKind, username: String) -> [CredentialRow] {
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

    func clipboardSummary(username: String) -> String {
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
        static let smtp = 2025
    }

    private static let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "MailBridgeService")

    private let defaults: UserDefaults
    private let config: ConfigLoader

    @Published var accountEmail: String = ""
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

    private let bridgeProcess = MailBridgeProcess()
    private lazy var controlServer = MailBridgeControlServer(socketURL: MailBridgeProcess.controlSocketURL)
    private var entitlementObserver: Task<Void, Never>?
    private var identity: MailAccountIdentity?
    @Published private(set) var isCheckingMailbox = false

    @Published private(set) var isActivatingMailBridge: Bool = false
    @Published private(set) var lastError: String?

    @Published private(set) var syncState: MailBridgeSyncState = .upToDate

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
        self.credentials.password = config.getMailBridgePassword() ?? ""

        observeEntitlement()
        observeSyncEvents()
    }

    deinit {
        entitlementObserver?.cancel()
    }

    private func observeSyncEvents() {
        controlServer.onIncomingEvent = { [weak self] event in
            Task { @MainActor [weak self] in
                self?.onSyncChanges(event)
            }
        }

        controlServer.onChannelLost = { [weak self] in
            Task { @MainActor [weak self] in
                self?.handleBridgeError("the daemon closed the control channel")
            }
        }

        bridgeProcess.onTermination = { [weak self] reason in
            guard case .unexpected(let status) = reason else { return }
            self?.handleBridgeError("the daemon exited with status \(status)")
        }
    }

    private func handleBridgeError(_ reason: String) {
        guard viewState.isActive || isActivatingMailBridge else { return }

        Self.logger.error("Mail Bridge stopped unexpectedly: \(reason)")
        bridgeProcess.stop()
        controlServer.stop()
        syncState = .upToDate
        lastError = reason
        withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.failed) }
    }

    private func onSyncChanges(_ event: MailBridgeEvent) {
        switch event {
        case .syncStarted(let total):
            Self.logger.info("Mail Bridge sync started: \(total) new messages to download")
            syncState = .syncing(downloaded: 0, total: total, percent: 0)
 
        case .syncProgress(let downloaded, let total, let percent):
            Self.logger.info("Mail Bridge sync progress: \(downloaded)/\(total) (\(percent)%)")
            syncState = .syncing(downloaded: downloaded, total: total, percent: percent)

        case .syncFinished(let downloaded, let total, let code):
            // An empty code means the sync did everything it set out to do.
            if let code, !code.isEmpty {
                Self.logger.warning("Mail Bridge sync stopped early (\(code)) at \(downloaded)/\(total)")
                syncState = .interrupted(downloaded: downloaded, total: total)
            } else {
                Self.logger.info("Mail Bridge sync finished: \(downloaded)/\(total)")
                syncState = .upToDate
            }
        }
    }

    /// The daemon can die without anyone asking it to. When that happens the UI has to
    /// stop claiming Bridge is active, otherwise the user copies credentials that lead nowhere.
    private func observeEntitlement() {
        entitlementObserver = Task { @MainActor [weak self] in
            for await isEnabled in FeaturesService.shared.$mailEnabled.values {
                guard let self else { return }
                if !isEnabled {
                    if self.viewState.isActive { self.deactivate() }
                    self.identity = nil
                    self.viewState = .locked
                } else if self.viewState == .locked {
                    await self.loadIdentity()
                }
            }
        }
    }

    /// The bridge password is generated once and then reused: the daemon has to
    /// authenticate clients with the same value the user copied into their mail app.
    private func loadOrCreatePassword() -> String {
        if let stored = config.getMailBridgePassword(), !stored.isEmpty {
            return stored
        }

        let generated = MailboxCredentials.generatePassword()
        do {
            try config.setMailBridgePassword(password: generated)
        } catch {
            Self.logger.error("Could not persist the Mail Bridge password: \(error)")
        }
        return generated
    }

    var progress: Double {
        switch syncState {
        case .upToDate:
            return 1
        case .syncing(_, _, let percent):
            return Double(percent) / 100
        case .interrupted(let downloaded, let total):
            return total > 0 ? Double(downloaded) / Double(total) : 0
        }
    }

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
        switch syncState {
        case .upToDate:
            return NSLocalizedString("MAIL_BRIDGE_UP_TO_DATE", comment: "Nothing left to sync")

        case .syncing(let downloaded, let total, let percent):
            return String(
                format: NSLocalizedString("MAIL_BRIDGE_SYNCING_%d_%@_%@", comment: "Mailbox sync progress"),
                percent,
                downloaded.formatted(),
                total.formatted()
            )

        case .interrupted(let downloaded, let total):
            return String(
                format: NSLocalizedString("MAIL_BRIDGE_SYNC_INTERRUPTED_%@_%@", comment: "A sync gave up partway"),
                downloaded.formatted(),
                total.formatted()
            )
        }
    }

    // MARK: - Actions
    func activate() async {
        guard FeaturesService.shared.mailEnabled else {
            Self.logger.warning("Refusing to start Mail Bridge: the plan does not include it")
            viewState = .locked
            return
        }
        guard !isActivatingMailBridge, !viewState.isActive else { return }

        isActivatingMailBridge = true
        lastError = nil
        defer { isActivatingMailBridge = false }

        do {
            let session = try await createSession()

            // Order matters:
            // 1. Create the socket
            try await controlServer.listen()
        
            // 2. Start the process (Mail Bridge daemon)
            try bridgeProcess.start()

            let daemonConfig = try await controlServer.handshake(session: session)
            applyBridgePorts(daemonConfig)

            Self.logger.info("Mail Bridge is ready on \(daemonConfig.imapAddress)")
            withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.active) }
        } catch {
            Self.logger.error("Could not start the Mail Bridge daemon: \(error)")
            bridgeProcess.stop()
            controlServer.stop()

            if case MailBridgeServiceError.mailboxNotCreated = error {
                lastError = nil
                withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.identitySetup) }
            } else {
                lastError = error.localizedDescription
                withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.failed) }
            }
        }
    }

    private func createSession() async throws -> MailBridgeSession {
        guard let token = config.getAuthToken(), !token.isEmpty else {
            throw MailBridgeServiceError.notSignedIn
        }

        guard let identity else { throw MailBridgeServiceError.mailboxNotCreated }

        if credentials.password.isEmpty {
            credentials.password = loadOrCreatePassword()
        }
        return MailBridgeSession(
            accountId: identity.address,
            addresses: [identity.address],
            backendSession: .init(
                token: token,
                encryptionPrivateKey: Data(identity.privateKey).base64EncodedString(),
                encryptionPublicKey: identity.publicKey
            ),
            mailClient: .init(username: identity.address, password: credentials.password)
        )
    }

    private func applyBridgePorts(_ ready: MailBridgeReady) {
        if let port = Int(ready.imapAddress.split(separator: ":").last ?? "") {
            imapPort = port
            credentials.imapPort = port
        }
        if let port = Int(ready.smtpAddress.split(separator: ":").last ?? "") {
            smtpPort = port
            credentials.smtpPort = port
        }
        credentials.imapSecurity = ready.startTLS ? "STARTTLS" : "None"
        credentials.smtpSecurity = ready.startTLS ? "STARTTLS" : "None"
    }

    func deactivate() {
        bridgeProcess.stop()
        controlServer.stop()
        activateAtLaunch = false
        syncState = .upToDate
        withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.inactive) }
    }

    func startIfNeeded() async {
        guard activateAtLaunch else {
            Self.logger.info("Mail Bridge autostart is off")
            return
        }

        Self.logger.info("Mail Bridge autostart is on, starting the daemon")
        await activate()
    }

    func reset() {
        bridgeProcess.stop()
        controlServer.stop()
        activateAtLaunch = false
        imapPort = DefaultPorts.imap
        smtpPort = DefaultPorts.smtp
        accountEmail = ""
        credentials = MailboxCredentials()
        credentials.imapPort = imapPort
        credentials.smtpPort = smtpPort
        syncState = .upToDate
        identity = nil
        viewState = .locked
    }

    private func loadIdentity() async {
        guard identity == nil else { return }

        isCheckingMailbox = true
        defer { isCheckingMailbox = false }
        
        do {
            let mnemonic = try config.getValidMnemonic()
            let keys = try await APIFactory.Mail.getMailAccountKeys()
            let privateKey = try MailKeystore.openEncryptionKeystore(
                address: keys.address,
                publicKey: keys.publicKey,
                encryptedPrivateKey: keys.encryptionPrivateKey,
                mnemonic: mnemonic
            )

            identity = MailAccountIdentity(
                address: keys.address,
                publicKey: keys.publicKey,
                privateKey: privateKey
            )
            accountEmail = keys.address
            Self.logger.info("Mail identity ready")
            withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.inactive) }

        } catch let apiError as APIClientError where apiError.isMailNotSetUp {
            Self.logger.info("The account has no Internxt Mail address yet")
            withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.identitySetup) }

        } catch {
            Self.logger.warning("Could not load the mail identity: \(error)")
            withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.inactive) }
        }
    }

    /// Asks again after the user says they created their address — the very same load.
    func recheckUserIdentitySetup() async {
        guard viewState == .unlocked(.identitySetup) else { return }
        await loadIdentity()
    }

    func retryAfterFailure() async {
        guard viewState == .unlocked(.failed) else { return }
        await activate()
    }

    func dismissFailure() {
        guard viewState == .unlocked(.failed) else { return }
        lastError = nil
        withAnimation(.easeOut(duration: 0.18)) { viewState = .unlocked(.inactive) }
    }

    func resyncMailManually() {
        lastError = nil
        do {
            try controlServer.resync()
        } catch {
            Self.logger.error("Could not ask Mail Bridge to resync: \(error)")
            lastError = error.localizedDescription
        }
    }


}

enum MailBridgeServiceError: Error, LocalizedError {
    case notSignedIn
    case mailboxNotCreated

    var errorDescription: String? {
        switch self {
        case .notSignedIn: return "Sign in to Internxt before starting Mail Bridge"
        case .mailboxNotCreated: return "This account has no Internxt Mail address yet"
        }
    }
}
