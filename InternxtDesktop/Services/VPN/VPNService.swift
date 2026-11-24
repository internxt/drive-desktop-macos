//
//  VPNService.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import AppKit
import Combine
import InternxtSwiftCore
import SwiftUI

extension VPNZone {
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
    let location: VPNZone
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

enum VPNZonesError: Error {
    case sessionExpired
}

enum VPNViewState: Equatable {
    case checkingAvailability
    case disconnected
    case needsApproval
    case connecting(VPNZone)
    case connected(VPNZone, since: Date, exit: ExitInfo?)
    case reconnecting(VPNZone)
    case disconnecting
    case failed(VPNError)
}

@MainActor
final class VPNService: ObservableObject {
    private static let logger = LogService.shared.createLogger(subsystem: .VPN, category: "VPNService")
    private static let lastRegionKey = "VPNService.lastRegion"
    private static let freeZones: Set<VPNZone> = [.france]

    private static var approvalSettingsURL: URL {
        if #available(macOS 15, *) {
            return URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!
        }
        return URL(string: "x-apple.systempreferences:com.apple.preference.security")!
    }

    @Published var viewState: VPNViewState
    @Published var regions: [VPNRegion]
    @Published var selectedRegion: VPNZone
    @Published var isFreePlan: Bool

    private let tunnel: VPNTunnel
    private let isEnabled: Bool
    private let connectTimeout: Duration
    private let authToken: () -> String?
    private let proxyURL: () -> URL?
    private let now: () -> Date
    private let defaults: UserDefaults
    private let vpnEntitlement: AnyPublisher<Bool, Never>
    private let fetchZones: () async throws -> [VPNZone]

    private var session: VPNSession?
    private var attempt: Task<Void, Never>?
    private var pendingStop: Task<Void, Never>?
    private var tokenObserver: Task<Void, Never>?
    private var entitlementObserver: Task<Void, Never>?
    private var hasVPNPlan = false

    init(
        viewState: VPNViewState = .disconnected,
        regions: [VPNRegion] = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) },
        selectedRegion: VPNZone = .france,
        isFreePlan: Bool = true,
        tunnel: VPNTunnel = SystemVPNTunnel(),
        isEnabled: Bool = ConfigLoader.isVPNEnabled,
        connectTimeout: Duration = .seconds(30),
        authToken: @escaping () -> String? = { ConfigLoader().getAuthToken() },
        proxyURL: @escaping () -> URL? = { ConfigLoader().get().VPN_PROXY_URL.flatMap { URL(string: $0) } },
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard,
        vpnEntitlement: AnyPublisher<Bool, Never> = FeaturesService.shared.$vpnEnabled.eraseToAnyPublisher(),
        fetchZones: @escaping () async throws -> [VPNZone] = VPNService.fetchZonesFromBackend
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
        self.defaults = defaults
        self.vpnEntitlement = vpnEntitlement
        self.fetchZones = fetchZones

        tunnel.onFailure = { [weak self] failure in self?.tunnelFailed(failure) }
        tunnel.onUnexpectedStop = { [weak self] in self?.tunnelStoppedOnItsOwn() }
    }

    deinit {
        tokenObserver?.cancel()
        entitlementObserver?.cancel()
        attempt?.cancel()
    }

    func start() {
        guard isEnabled, entitlementObserver == nil else { return }

        if let stored = defaults.string(forKey: Self.lastRegionKey).flatMap(VPNZone.init(rawValue:)) {
            selectedRegion = stored
        }
        viewState = .checkingAvailability
        observeTokenRefresh()
        observeEntitlement()
    }

    func select(_ region: VPNRegion) {
        guard region.isAvailable else {
            URLDictionary.UPGRADE_PLAN.open()
            return
        }
        guard region.location != selectedRegion else { return }

        selectedRegion = region.location
        defaults.set(region.location.rawValue, forKey: Self.lastRegionKey)
        if case .connected = viewState {
            switchRegion()
        }
    }

    func refreshRegions() async {
        guard let zones = await availableZones() else { return }

        regions = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: zones.contains($0)) }
        isFreePlan = !hasVPNPlan
        if !zones.contains(selectedRegion) {
            selectedRegion = .france
        }
        if viewState == .checkingAvailability {
            viewState = .disconnected
        }
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
        beginConnection(token: token, proxyHost: host, proxyPort: port)
    }

    private func beginConnection(token: String, proxyHost host: String, proxyPort port: UInt16) {
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
        guard isEnabled, await tunnel.isRunning(), attempt == nil, session == nil else { return }
        Self.logger.info("Disconnecting a VPN tunnel left over from a previous session")
        stopTunnelInBackground()
        await pendingStop?.value
    }

    func reset() {
        guard isEnabled else { return }
        stopNow()
        defaults.removeObject(forKey: Self.lastRegionKey)
        selectedRegion = .france
        hasVPNPlan = false
        isFreePlan = true
        regions = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: Self.freeZones.contains($0)) }
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
        if failure == .zoneNotAllowed {
            Task { [weak self] in
                await self?.refreshRegions()
            }
        }
    }

    private func switchRegion() {
        guard let current = session else { return }
        Self.logger.info("Switching the VPN to \(selectedRegion.rawValue)")
        attempt?.cancel()
        session = nil
        viewState = .connecting(selectedRegion)
        attempt = Task { [weak self] in
            await self?.tunnel.stop()
            guard !Task.isCancelled else { return }
            self?.beginConnection(token: current.token, proxyHost: current.proxyHost, proxyPort: current.proxyPort)
        }
    }

    private func observeEntitlement() {
        entitlementObserver = Task { [weak self, vpnEntitlement] in
            for await isEnabled in vpnEntitlement.values {
                guard let self else { return }
                self.hasVPNPlan = isEnabled
                await self.refreshRegions()
            }
        }
    }

    private func availableZones() async -> Set<VPNZone>? {
        guard hasVPNPlan else { return Self.freeZones }
        do {
            return Set(try await fetchZones())
        } catch VPNZonesError.sessionExpired {
            Self.logger.error("Could not load the VPN regions: session expired")
            if viewState.acceptsConnect || viewState == .checkingAvailability {
                viewState = .failed(.sessionExpired)
            }
            return nil
        } catch {
            Self.logger.error("Could not load the VPN regions, falling back to the free ones: \(error)")
            return Self.freeZones
        }
    }

    nonisolated static func fetchZonesFromBackend() async throws -> [VPNZone] {
        do {
            return try await APIFactory.VPN.getUser().zones
        } catch let error as APIClientError where error.statusCode == 401 {
            throw VPNZonesError.sessionExpired
        }
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
