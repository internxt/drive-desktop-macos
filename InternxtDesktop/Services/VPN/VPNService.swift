//
//  VPNService.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import AppKit
import SwiftUI

enum VPNLocation: String, CaseIterable {
    case france = "FR"
    case germany = "DE"
    case poland = "PL"
    case canada = "CA"
    case unitedKingdom = "UK"

    var nameKey: String { "VPN_REGION_\(rawValue)" }

    var flag: String {
        switch self {
        case .france: return "🇫🇷"
        case .germany: return "🇩🇪"
        case .poland: return "🇵🇱"
        case .canada: return "🇨🇦"
        case .unitedKingdom: return "🇬🇧"
        }
    }
}

struct VPNRegion: Identifiable, Equatable {
    let location: VPNLocation
    let isAvailable: Bool

    var id: String { location.rawValue }
}

struct ExitInfo: Equatable {
    let ip: String
    let location: String
}

enum VPNError: Equatable {
    case extensionNotApproved
    case sessionExpired
    case zoneNotPermitted
    case proxyUnreachable
    case unknown
}

enum VPNViewState: Equatable {
    case checkingAvailability
    case disconnected
    case needsApproval
    case connecting(VPNLocation)
    case connected(VPNLocation, since: Date, exit: ExitInfo?)
    case reconnecting(VPNLocation)
    case disconnecting
    case failed(VPNError)
}

@MainActor
final class VPNService: ObservableObject {
    private static let logger = LogService.shared.createLogger(subsystem: .VPN, category: "VPNService")

    private static var approvalSettingsURL: URL {
        if #available(macOS 15, *) {
            return URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security")!
    }

    @Published var viewState: VPNViewState
    @Published var regions: [VPNRegion]
    @Published var selectedRegion: VPNLocation
    @Published var isFreePlan: Bool

    private let tunnel: VPNTunnel
    private let isEnabled: Bool
    private let connectTimeout: Duration
    private let authToken: () -> String?
    private let proxyURL: () -> URL?
    private let now: () -> Date

    private var session: VPNSession?
    private var attempt: Task<Void, Never>?
    private var pendingStop: Task<Void, Never>?
    private var tokenObserver: Task<Void, Never>?

    init(
        viewState: VPNViewState = .disconnected,
        regions: [VPNRegion] = VPNLocation.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) },
        selectedRegion: VPNLocation = .france,
        isFreePlan: Bool = true,
        tunnel: VPNTunnel = SystemVPNTunnel(),
        isEnabled: Bool = ConfigLoader.isVPNEnabled,
        connectTimeout: Duration = .seconds(30),
        authToken: @escaping () -> String? = { ConfigLoader().getAuthToken() },
        proxyURL: @escaping () -> URL? = { ConfigLoader().get().VPN_PROXY_URL.flatMap { URL(string: $0) } },
        now: @escaping () -> Date = Date.init
    ) {
        self.viewState = viewState
        self.regions = regions
        self.selectedRegion = selectedRegion
        self.isFreePlan = isFreePlan
        self.tunnel = tunnel
        self.isEnabled = isEnabled
        self.connectTimeout = connectTimeout
        self.authToken = authToken
        self.proxyURL = proxyURL
        self.now = now

        tunnel.onFailure = { [weak self] failure in self?.tunnelFailed(failure) }
        tunnel.onUnexpectedStop = { [weak self] in self?.tunnelStoppedOnItsOwn() }
        if isEnabled {
            observeTokenRefresh()
        }
    }

    deinit {
        tokenObserver?.cancel()
        attempt?.cancel()
    }

    func select(_ region: VPNRegion) {
        guard region.isAvailable else {
            URLDictionary.UPGRADE_PLAN.open()
            return
        }
        selectedRegion = region.location
    }

    func openApprovalSettings() {
        NSWorkspace.shared.open(Self.approvalSettingsURL)
    }

    func connect() {
        guard isEnabled, viewState.acceptsConnect else { return }

        guard let token = authToken(), !token.isEmpty else {
            Self.logger.error("Cannot connect the VPN without a session token")
            viewState = .failed(.sessionExpired)
            return
        }
        guard let proxy = proxyURL(), let host = proxy.host, let port = proxy.port.flatMap(UInt16.init(exactly:)) else {
            Self.logger.error("Cannot connect the VPN: the proxy address is not configured")
            viewState = .failed(.proxyUnreachable)
            return
        }

        let session = VPNSession(proxyHost: host, proxyPort: port, location: selectedRegion, token: token)
        Self.logger.info("Connecting the VPN to \(session.location.rawValue)")
        viewState = .connecting(session.location)
        attempt?.cancel()
        attempt = Task { [weak self] in
            await self?.establish(session)
        }
    }

    func disconnect() {
        guard isEnabled, viewState.acceptsDisconnect else { return }

        Self.logger.info("Disconnecting the VPN")
        attempt?.cancel()
        attempt = nil
        session = nil
        viewState = .disconnecting
        Task { [weak self] in
            await self?.tunnel.stop()
            guard let self, self.viewState == .disconnecting else { return }
            self.viewState = .disconnected
        }
    }

    func retry() {
        guard case .failed = viewState else { return }
        viewState = .disconnected
        connect()
    }

    func disconnectLeftoverTunnel() async {
        guard isEnabled, await tunnel.isRunning(), viewState == .disconnected else { return }
        Self.logger.info("Disconnecting a VPN tunnel left over from a previous session")
        stopTunnelInBackground()
        await pendingStop?.value
    }

    func reset() {
        guard isEnabled else { return }
        stopNow()
        viewState = .disconnected
    }

    func shutdown() {
        guard isEnabled else { return }
        stopNow()
    }

    private func establish(_ session: VPNSession) async {
        await pendingStop?.value
        guard !Task.isCancelled else { return }
        do {
            try await tunnel.activateExtension(onNeedsApproval: { [weak self] in
                guard let self, self.attempt != nil else { return }
                self.viewState = .needsApproval
            })
            guard !Task.isCancelled else { return }
            viewState = .connecting(session.location)

            let timeout = Task { [weak self, connectTimeout] in
                try? await Task.sleep(for: connectTimeout)
                guard !Task.isCancelled else { return }
                self?.connectionTimedOut()
            }
            defer { timeout.cancel() }

            try await tunnel.start(session)
            guard !Task.isCancelled else { return }
            self.session = session
            attempt = nil
            Self.logger.info("VPN connected to \(session.location.rawValue)")
            viewState = .connected(session.location, since: now(), exit: nil)
            handOverRefreshedToken()
        } catch {
            guard !Task.isCancelled else { return }
            Self.logger.error("VPN connection failed: \(error)")
            attempt = nil
            viewState = .failed(Self.viewError(for: error))
            stopTunnelInBackground()
        }
    }

    private func stopTunnelInBackground() {
        let previous = pendingStop
        pendingStop = Task { [tunnel] in
            await previous?.value
            await tunnel.stop()
        }
    }

    private func connectionTimedOut() {
        guard case .connecting = viewState else { return }
        Self.logger.error("VPN connection timed out")
        attempt?.cancel()
        attempt = nil
        viewState = .failed(.proxyUnreachable)
        stopTunnelInBackground()
    }

    private func tunnelFailed(_ failure: VPNTunnelFailure) {
        guard session != nil else { return }
        Self.logger.error("VPN extension reported a failure: \(failure.rawValue)")
        session = nil
        viewState = .failed(Self.viewError(for: failure))
        stopTunnelInBackground()
    }

    private func tunnelStoppedOnItsOwn() {
        guard session != nil else { return }
        session = nil
        viewState = .disconnected
    }

    private func stopNow() {
        attempt?.cancel()
        attempt = nil
        session = nil
        tunnel.stopImmediately()
    }

    private func observeTokenRefresh() {
        tokenObserver = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .authTokenDidChange) {
                self?.handOverRefreshedToken()
            }
        }
    }

    private func handOverRefreshedToken() {
        guard let session, let token = authToken(), !token.isEmpty, token != session.token else { return }
        let refreshed = session.refreshed(with: token)
        self.session = refreshed
        tunnel.updateSession(refreshed)
        Self.logger.info("Refreshed token handed to the VPN extension")
    }

    private static func viewError(for failure: VPNTunnelFailure) -> VPNError {
        switch failure {
        case .sessionExpired: return .sessionExpired
        case .zoneNotAllowed: return .zoneNotPermitted
        case .proxyUnreachable: return .proxyUnreachable
        }
    }

    private static func viewError(for error: Error) -> VPNError {
        switch error {
        case VPNTunnelError.notApproved: return .extensionNotApproved
        case VPNTunnelError.failedToStart: return .proxyUnreachable
        default: return .unknown
        }
    }
}

private extension VPNViewState {
    var acceptsConnect: Bool {
        switch self {
        case .disconnected, .failed: return true
        default: return false
        }
    }

    var acceptsDisconnect: Bool {
        switch self {
        case .connected, .connecting, .needsApproval, .reconnecting: return true
        default: return false
        }
    }
}
