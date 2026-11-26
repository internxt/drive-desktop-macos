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

struct PublicAddress: Equatable, Decodable {
    let ip: String
    let location: String

    private enum CodingKeys: String, CodingKey {
        case ip, city, region, country
    }

    init(ip: String, location: String) {
        self.ip = ip
        self.location = location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ip = try container.decode(String.self, forKey: .ip)
        guard !ip.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .ip, in: container, debugDescription: "Empty IP")
        }
        location = [CodingKeys.city, .region, .country]
            .compactMap { try? container.decodeIfPresent(String.self, forKey: $0) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

enum PublicAddressLookup: Equatable {
    case loading
    case unavailable
    case found(PublicAddress)
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
    case connecting(VPNZone)
    case connected(VPNZone, since: Date, publicAddress: PublicAddressLookup)
    case reconnecting(VPNZone)
    case disconnecting
    case failed(VPNError)
}

@MainActor
final class VPNService: ObservableObject {
    private static let logger = LogService.shared.createLogger(subsystem: .VPN, category: "VPNService")
    private static let preferredRegionKey = "VPNService.lastRegion"
    private static let freeZones: Set<VPNZone> = [.france]

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
        case awaitingApproval
        case awaitingStop
        case starting
        case up(since: Date)
    }

    @Published var viewState: VPNViewState
    @Published var regions: [VPNRegion]
    @Published var selectedRegion: VPNZone
    @Published var isFreePlan: Bool

    private let tunnel: VPNTunnel
    private let isEnabled: Bool
    private let connectTimeout: Duration
    private let authToken: () -> String?
    private let configuration: () -> VPNConfiguration
    private let now: () -> Date
    private let defaults: UserDefaults
    private let vpnEntitlement: AnyPublisher<Bool, Never>
    private let fetchZones: () async throws -> [VPNZone]
    private let fetchPublicAddress: () async throws -> PublicAddress

    private var goal = Goal.off
    private var zones: Set<VPNZone>? = VPNService.freeZones
    private var hasVPNPlan = false
    private var failure: VPNError?
    private var connectDeadline: Task<Void, Never>?
    private var preparation: Task<Void, Never>?
    private var tokenObserver: Task<Void, Never>?
    private var entitlementObserver: Task<Void, Never>?
    private var publicAddress = PublicAddressLookup.loading
    private var publicAddressRequest: Task<Void, Never>?

    init(
        viewState: VPNViewState = .disconnected,
        regions: [VPNRegion] = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) },
        selectedRegion: VPNZone = .france,
        isFreePlan: Bool = true,
        tunnel: VPNTunnel = SystemVPNTunnel(),
        isEnabled: Bool = ConfigLoader.isVPNEnabled,
        connectTimeout: Duration = .seconds(30),
        authToken: @escaping () -> String? = { ConfigLoader().getAuthToken() },
        configuration: @escaping () -> VPNConfiguration = { ConfigLoader().getVPNConfiguration() },
        now: @escaping () -> Date = Date.init,
        defaults: UserDefaults = .standard,
        vpnEntitlement: AnyPublisher<Bool, Never> = FeaturesService.shared.$vpnEnabled.eraseToAnyPublisher(),
        fetchZones: @escaping () async throws -> [VPNZone] = { try await APIFactory.VPN.getUser().zones },
        fetchPublicAddress: @escaping () async throws -> PublicAddress = VPNService.fetchPublicAddressFromIPService
    ) {
        self.viewState = viewState
        self.regions = regions
        self.selectedRegion = selectedRegion
        self.isFreePlan = isFreePlan
        self.tunnel = tunnel
        self.isEnabled = isEnabled
        self.connectTimeout = connectTimeout
        self.authToken = authToken
        self.configuration = configuration
        self.now = now
        self.defaults = defaults
        self.vpnEntitlement = vpnEntitlement
        self.fetchZones = fetchZones
        self.fetchPublicAddress = fetchPublicAddress

        tunnel.onStatusChange = { [weak self] status in self?.tunnelChanged(to: status) }
        tunnel.onFailure = { [weak self] failure in self?.extensionFailed(failure) }
    }

    deinit {
        tokenObserver?.cancel()
        entitlementObserver?.cancel()
        connectDeadline?.cancel()
        publicAddressRequest?.cancel()
    }

    func start() {
        guard isEnabled, entitlementObserver == nil else { return }
        zones = nil
        render()
        observeTokenRefresh()
        observeEntitlement()
        Task { [weak self] in
            await self?.tunnel.load()
        }
    }

    func select(_ region: VPNRegion) {
        guard region.isAvailable else {
            URLDictionary.UPGRADE_PLAN.open()
            return
        }
        defaults.set(region.location.rawValue, forKey: Self.preferredRegionKey)
        selectedRegion = region.location
        if case .on(var session, let step) = goal, session.location != region.location {
            session.location = region.location
            goal = .on(session, step)
            tunnel.update(session)
            if case .up = step {
                lookUpPublicAddress()
            }
        }
        render()
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
        let proxy = configuration()
        let session = VPNSession(proxyHost: proxy.proxyHost, proxyPort: proxy.proxyPort, location: selectedRegion, token: token)
        Self.logger.info("Connecting the VPN to \(session.location.rawValue)")
        failure = nil
        goal = .on(session, .preparing)
        render()
        guard preparation == nil else { return }
        preparation = Task { [weak self] in
            await self?.prepareWhileWanted()
            self?.preparation = nil
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

    func reset() {
        guard isEnabled else { return }
        turnOff()
        defaults.removeObject(forKey: Self.preferredRegionKey)
        hasVPNPlan = false
        apply(Self.freeZones)
    }

    func shutdown() {
        guard isEnabled else { return }
        goal = .off
        tunnel.stop()
    }

    private func prepareWhileWanted() async {
        while case .on(let session, .preparing) = goal {
            do {
                try await tunnel.prepare(session, onNeedsApproval: { [weak self] in
                    guard let self, case .on(let current, .preparing) = self.goal else { return }
                    self.goal = .on(current, .awaitingApproval)
                    self.render()
                })
            } catch is CancellationError {
                continue
            } catch {
                guard case .on = goal else { return }
                Self.logger.error("Could not prepare the VPN: \(error)")
                turnOff(failing: Self.viewError(for: error))
                return
            }
            tunnelPrepared()
            return
        }
    }

    private func tunnelPrepared() {
        guard case .on(let current, let step) = goal, step == .preparing || step == .awaitingApproval else { return }
        if tunnel.status == .disconnected {
            start(current)
        } else {
            goal = .on(current, .awaitingStop)
            startConnectDeadline()
            tunnel.stop()
            render()
        }
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
        case .off:
            if status.isActive, status != .disconnecting {
                Self.logger.info("Stopping a VPN tunnel the app did not ask for")
                tunnel.stop()
            }
        case .on(let session, .awaitingStop):
            if status == .disconnected {
                start(session)
                return
            }
        case .on(let session, .starting):
            if status == .connected {
                connectDeadline?.cancel()
                goal = .on(session, .up(since: now()))
                Self.logger.info("VPN connected to \(session.location.rawValue)")
                handOverRefreshedToken()
                lookUpPublicAddress()
            } else if status == .disconnected {
                Self.logger.error("The VPN stopped before connecting")
                turnOff(failing: .proxyUnreachable)
                return
            }
        case .on(_, .up):
            if status == .connected {
                lookUpPublicAddress()
            } else if status == .disconnected {
                Self.logger.info("The VPN stopped without the app asking")
                goal = .off
            }
        case .on(_, .preparing), .on(_, .awaitingApproval):
            break
        }
        render()
    }

    private func extensionFailed(_ failure: VPNTunnelFailure) {
        guard case .on = goal else { return }
        if failure == .proxyUnreachable, tunnel.status == .reconnecting { return }
        Self.logger.error("VPN extension reported a failure: \(failure.rawValue)")
        turnOff(failing: Self.viewError(for: failure))
        if failure == .zoneNotAllowed {
            Task { [weak self] in
                await self?.loadZones()
            }
        }
    }

    nonisolated static func fetchPublicAddressFromIPService() async throws -> PublicAddress {
        guard let base = ConfigLoader().get().VPN_IP_API_URL, let baseURL = URL(string: base) else {
            throw URLError(.badURL)
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        let (data, response) = try await session.data(from: baseURL.appendingPathComponent("json"))
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(PublicAddress.self, from: data)
    }

    private func observeEntitlement() {
        entitlementObserver = Task { [weak self, vpnEntitlement] in
            for await hasPlan in vpnEntitlement.values {
                guard let self else { return }
                self.hasVPNPlan = hasPlan
                await self.loadZones()
            }
        }
    }

    private func loadZones() async {
        guard hasVPNPlan else {
            apply(Self.freeZones)
            return
        }
        do {
            let fetched = try await fetchZones()
            guard hasVPNPlan else { return }
            apply(Set(fetched))
        } catch {
            guard hasVPNPlan else { return }
            Self.logger.error("Could not load the VPN regions: \(error)")
            apply(zones ?? Self.freeZones)
        }
    }

    private func apply(_ planZones: Set<VPNZone>) {
        let available = planZones.union(Self.freeZones)
        zones = available
        regions = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: available.contains($0)) }
        isFreePlan = !hasVPNPlan
        let preferred = defaults.string(forKey: Self.preferredRegionKey).flatMap(VPNZone.init(rawValue:))
        selectedRegion = preferred.flatMap { available.contains($0) ? $0 : nil } ?? .france
        if case .on(let session, _) = goal, !available.contains(session.location) {
            Self.logger.error("The VPN region \(session.location.rawValue) is no longer in the plan")
            turnOff(failing: .zoneNotPermitted)
            return
        }
        render()
    }

    private func lookUpPublicAddress() {
        publicAddressRequest?.cancel()
        publicAddress = .loading
        publicAddressRequest = Task { [weak self, fetchPublicAddress] in
            let found: PublicAddressLookup
            do {
                found = .found(try await fetchPublicAddress())
            } catch {
                Self.logger.error("Could not look up the VPN public address: \(error)")
                found = .unavailable
            }
            guard !Task.isCancelled, let self, case .on(_, .up) = self.goal else { return }
            self.publicAddress = found
            self.render()
        }
    }

    private func turnOff(failing error: VPNError? = nil) {
        connectDeadline?.cancel()
        publicAddressRequest?.cancel()
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
        guard case .on(_, let step) = goal, step == .awaitingStop || step == .starting else { return }
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
            } else if zones == nil {
                viewState = .checkingAvailability
            } else {
                viewState = .disconnected
            }
        case .on(_, .awaitingApproval):
            viewState = .needsApproval
        case .on(let session, .up(let since)):
            switch tunnel.status {
            case .reconnecting: viewState = .reconnecting(session.location)
            case .disconnecting: viewState = .disconnecting
            default: viewState = .connected(session.location, since: since, publicAddress: publicAddress)
            }
        case .on(let session, _):
            viewState = .connecting(session.location)
        }
    }

    private func observeTokenRefresh() {
        tokenObserver = Task { @MainActor [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .authTokenDidChange) {
                self?.handOverRefreshedToken()
            }
        }
    }

    private func handOverRefreshedToken() {
        guard case .on(let session, let step) = goal, let token = authToken(), !token.isEmpty, token != session.token else { return }
        var refreshed = session
        refreshed.token = token
        goal = .on(refreshed, step)
        tunnel.update(refreshed)
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
