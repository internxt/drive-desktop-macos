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

    private enum Goal {
        case off
        case on(VPNSession, Step)
    }

    private enum Step: Equatable {
        case preparing
        case starting
        case up(since: Date)
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

    private var goal = Goal.off
    private var failure: VPNError?
    private var connectDeadline: Task<Void, Never>?

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

        tunnel.onStatusChange = { [weak self] status in self?.tunnelChanged(to: status) }
        tunnel.onFailure = { [weak self] failure in self?.extensionFailed(failure) }
    }

    deinit {
        connectDeadline?.cancel()
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
            turnOff(failing: .sessionExpired)
            return
        }
        guard let proxy = proxyURL(), let host = proxy.host, let port = proxy.port.flatMap(UInt16.init(exactly:)), port > 0 else {
            Self.logger.error("Cannot connect the VPN: the proxy address is not configured")
            turnOff(failing: .proxyUnreachable)
            return
        }

        let session = VPNSession(proxyHost: host, proxyPort: port, location: selectedRegion, token: token)
        Self.logger.info("Connecting the VPN to \(session.location.rawValue)")
        failure = nil
        goal = .on(session, .preparing)
        render()
        Task { [weak self] in
            await self?.prepare(session)
        }
    }

    func disconnect() {
        guard isEnabled, viewState.acceptsDisconnect else { return }
        Self.logger.info("Disconnecting the VPN")
        turnOff()
    }

    func retry() {
        guard case .failed = viewState else { return }
        connect()
    }

    private func prepare(_ session: VPNSession) async {
        do {
            try await tunnel.prepare(session, onNeedsApproval: {})
        } catch is CancellationError {
            return
        } catch {
            guard case .on = goal else { return }
            Self.logger.error("Could not prepare the VPN: \(error)")
            turnOff(failing: Self.viewError(for: error))
            return
        }
        guard case .on(let current, .preparing) = goal else { return }
        start(current)
    }

    private func start(_ session: VPNSession) {
        do {
            try tunnel.start(session)
            goal = .on(session, .starting)
            startConnectDeadline()
            render()
        } catch {
            Self.logger.error("Could not start the VPN: \(error)")
            turnOff(failing: .proxyUnreachable)
        }
    }

    private func tunnelChanged(to status: VPNTunnelStatus) {
        switch goal {
        case .on(let session, .starting):
            if status == .connected {
                connectDeadline?.cancel()
                goal = .on(session, .up(since: now()))
                Self.logger.info("VPN connected to \(session.location.rawValue)")
            } else if status == .disconnected {
                Self.logger.error("The VPN stopped before connecting")
                turnOff(failing: .proxyUnreachable)
                return
            }
        case .on(_, .up):
            if status == .disconnected {
                Self.logger.info("The VPN stopped without the app asking")
                goal = .off
            }
        case .off, .on(_, .preparing):
            break
        }
        render()
    }

    private func extensionFailed(_ failure: VPNTunnelFailure) {
        guard case .on = goal else { return }
        Self.logger.error("VPN extension reported a failure: \(failure.rawValue)")
        turnOff(failing: Self.viewError(for: failure))
    }

    private func turnOff(failing error: VPNError? = nil) {
        connectDeadline?.cancel()
        goal = .off
        failure = error
        tunnel.stop()
        render()
    }

    private func startConnectDeadline() {
        connectDeadline?.cancel()
        connectDeadline = Task { [weak self, connectTimeout] in
            try? await Task.sleep(for: connectTimeout)
            guard !Task.isCancelled else { return }
            self?.connectionTimedOut()
        }
    }

    private func connectionTimedOut() {
        guard case .on(_, .starting) = goal else { return }
        Self.logger.error("VPN connection timed out")
        turnOff(failing: .proxyUnreachable)
    }

    private func render() {
        switch goal {
        case .off:
            if tunnel.status.isActive {
                viewState = .disconnecting
            } else if let failure {
                viewState = .failed(failure)
            } else {
                viewState = .disconnected
            }
        case .on(let session, .up(let since)):
            switch tunnel.status {
            case .reconnecting: viewState = .reconnecting(session.location)
            case .disconnecting: viewState = .disconnecting
            default: viewState = .connected(session.location, since: since, exit: nil)
            }
        case .on(let session, _):
            viewState = .connecting(session.location)
        }
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
        case .connected, .connecting, .reconnecting: return true
        default: return false
        }
    }
}
