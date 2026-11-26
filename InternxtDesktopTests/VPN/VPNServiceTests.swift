//
//  VPNServiceTests.swift
//  InternxtDesktopTests
//
//  Created by Xavier Abad Gomez on 24/11/2026.
//

import XCTest
@testable import Internxt

@MainActor
final class VPNServiceTests: XCTestCase {
    private let connectedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private var tunnel: FakeVPNTunnel!
    private var token: String?
    private var configuration: VPNConfiguration!

    override func setUp() async throws {
        tunnel = FakeVPNTunnel()
        token = "token-1"
        configuration = VPNConfiguration(proxyHost: "203.0.113.7", proxyPort: 8082)
    }

    func test_connect_withApprovedExtension_endsConnectedToFranceThroughTheConfiguredProxy() async {
        let service = makeService()

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, exit: nil))
        XCTAssertEqual(tunnel.startedSessions, [VPNSession(proxyHost: "203.0.113.7", proxyPort: 8082, location: .france, token: "token-1")])
    }

    func test_connect_showsConnectingUntilTheSystemReportsConnected() async {
        let service = makeService()

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemReports(.connecting)

        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_connect_whileTheSystemAsksToAllowTheConfiguration_doesNotTimeOut() async {
        tunnel.holdsPreparation = true
        let service = makeService(connectTimeout: .milliseconds(20))

        service.connect()
        await waitUntil { self.tunnel.preparedSessions.count == 1 }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(service.viewState, .connecting(.france))
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_connect_thatNeverConnects_failsAsProxyUnreachableAndStopsTheTunnel() async {
        let service = makeService(connectTimeout: .milliseconds(50))

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemReports(.connecting)

        await waitUntil { service.viewState == .disconnecting }
        XCTAssertEqual(tunnel.stopCount, 1)
        tunnel.systemStops()
        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
    }

    func test_connect_whenTheTunnelStopsBeforeConnecting_failsAsProxyUnreachable() async {
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }

        tunnel.systemReports(.connecting)
        tunnel.systemReports(.disconnected)

        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
    }

    func test_connect_afterAbandoningAnAttempt_isNotFailedByTheAbandonedAttemptsTimeout() async {
        let service = makeService(connectTimeout: .milliseconds(400))
        let firstAttempt = Date()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        service.disconnect()
        try? await Task.sleep(for: .milliseconds(200))

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 2 }
        let untilAfterTheFirstTimeout = 520 - Int(Date().timeIntervalSince(firstAttempt) * 1000)
        try? await Task.sleep(for: .milliseconds(max(untilAfterTheFirstTimeout, 0)))

        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_connect_whenTheProxyConfigurationIsDenied_showsExtensionNotApproved() async {
        tunnel.prepareError = VPNTunnelError.notApproved
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .failed(.extensionNotApproved) }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_connect_whenTheSystemRefusesToStart_showsProxyUnreachable() async {
        tunnel.startError = StartRefused()
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .failed(.proxyUnreachable) }
    }

    func test_connect_withoutSessionToken_failsAsSessionExpiredWithoutPreparing() async {
        token = nil
        let service = makeService()

        service.connect()

        XCTAssertEqual(service.viewState, .failed(.sessionExpired))
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(tunnel.preparedSessions.isEmpty)
    }

    func test_configuration_readsTheProxyHostAndPort() throws {
        let configuration = try VPNConfiguration(proxyURL: "http://203.0.113.7:8082")

        XCTAssertEqual(configuration, VPNConfiguration(proxyHost: "203.0.113.7", proxyPort: 8082))
    }

    func test_configuration_withoutProxyAddress_isMissing() {
        for value in [nil, ""] as [String?] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: value)) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .missing("VPN_PROXY_URL"))
            }
        }
    }

    func test_configuration_withAnUnusableProxyAddress_isInvalid() {
        for value in ["http://203.0.113.7:0", "http://203.0.113.7", "203.0.113.7:8082", "not a url"] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: value)) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .invalid("VPN_PROXY_URL"))
            }
        }
    }

    func test_connect_whenTheFeatureIsDisabled_doesNothing() async {
        let service = makeService(isEnabled: false)

        service.connect()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertTrue(tunnel.preparedSessions.isEmpty)
    }

    func test_disconnect_whileConnected_showsDisconnectingUntilTheSystemStops() async {
        let service = await connectedService()

        service.disconnect()

        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertEqual(service.viewState, .disconnecting)

        tunnel.systemStops()

        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_disconnect_whileConnecting_stopsTheTunnel() async {
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemReports(.connecting)

        service.disconnect()
        tunnel.systemStops()

        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_disconnect_whileReconnecting_stopsTheTunnelAndShowsDisconnected() async {
        let service = await connectedService()
        tunnel.systemReports(.reconnecting)
        XCTAssertEqual(service.viewState, .reconnecting(.france))

        service.disconnect()
        tunnel.systemStops()

        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_extensionReportingAFailure_showsItsErrorAndStopsTheTunnel() async {
        let expectations: [(VPNTunnelFailure, VPNError)] = [
            (.sessionExpired, .sessionExpired),
            (.proxyUnreachable, .proxyUnreachable),
            (.zoneNotAllowed, .zoneNotPermitted),
        ]
        for (failure, error) in expectations {
            tunnel = FakeVPNTunnel()
            let service = await connectedService()

            tunnel.onFailure?(failure)
            tunnel.systemStops()

            XCTAssertEqual(service.viewState, .failed(error))
            XCTAssertEqual(tunnel.stopCount, 1)
        }
    }

    func test_extensionFailureWhileDisconnected_isIgnored() async {
        let service = makeService()

        tunnel.onFailure?(.proxyUnreachable)

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_retry_afterAFailure_connectsAgain() async {
        let service = await connectedService()
        tunnel.onFailure?(.proxyUnreachable)
        tunnel.systemStops()

        service.retry()
        await waitUntil { self.tunnel.startedSessions.count == 2 }
        tunnel.systemConnects()

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, exit: nil))
    }

    func test_tunnelStoppingOnItsOwn_whileConnected_showsDisconnected() async {
        let service = await connectedService()

        tunnel.systemReports(.disconnecting)
        XCTAssertEqual(service.viewState, .disconnecting)
        tunnel.systemReports(.disconnected)

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    private func makeService(
        isEnabled: Bool = true,
        connectTimeout: Duration = .seconds(5)
    ) -> VPNService {
        VPNService(
            tunnel: tunnel,
            isEnabled: isEnabled,
            connectTimeout: connectTimeout,
            authToken: { [unowned self] in self.token },
            configuration: { [unowned self] in self.configuration },
            now: { [connectedAt] in connectedAt }
        )
    }

    private func connectedService() async -> VPNService {
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()
        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, exit: nil))
        return service
    }

    private func waitUntil(
        _ condition: @MainActor () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTAssertTrue(condition(), "Condition not met in time", file: file, line: line)
    }
}

private struct StartRefused: Error {}

@MainActor
private final class FakeVPNTunnel: VPNTunnel {
    private(set) var status = VPNTunnelStatus.disconnected
    var onStatusChange: ((VPNTunnelStatus) -> Void)?
    var onFailure: ((VPNTunnelFailure) -> Void)?

    var holdsPreparation = false
    var prepareError: Error?
    var startError: Error?
    private(set) var preparedSessions: [VPNSession] = []
    private(set) var startedSessions: [VPNSession] = []
    private(set) var stopCount = 0

    private var heldPreparation: CheckedContinuation<Void, Error>?

    func load() async {}

    func prepare(_ session: VPNSession, onNeedsApproval: @escaping @MainActor () -> Void) async throws {
        preparedSessions.append(session)
        if let prepareError {
            throw prepareError
        }
        if holdsPreparation {
            try await withCheckedThrowingContinuation { heldPreparation = $0 }
        }
    }

    func start(_ session: VPNSession) throws {
        if let startError {
            throw startError
        }
        guard !status.isActive else { return }
        startedSessions.append(session)
    }

    func update(_ session: VPNSession) {}

    func stop() {
        stopCount += 1
    }

    func systemReports(_ status: VPNTunnelStatus) {
        guard status != self.status else { return }
        self.status = status
        onStatusChange?(status)
    }

    func systemConnects() {
        systemReports(.connecting)
        systemReports(.connected)
    }

    func systemStops() {
        systemReports(.disconnecting)
        systemReports(.disconnected)
    }
}
