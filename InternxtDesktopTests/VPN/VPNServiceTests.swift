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
    private var proxyURL: URL?

    override func setUp() async throws {
        tunnel = FakeVPNTunnel()
        token = "token-1"
        proxyURL = URL(string: "http://203.0.113.7:8082")
    }

    func test_connect_withApprovedExtension_endsConnectedToFranceThroughTheConfiguredProxy() async {
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
        XCTAssertEqual(tunnel.startedSessions, [VPNSession(proxyHost: "203.0.113.7", proxyPort: 8082, location: .france, token: "token-1")])
    }

    func test_connect_showsConnectingWhileTheTunnelStarts() async {
        tunnel.startBehavior = .hangs
        let service = makeService()

        service.connect()

        await waitUntil { self.tunnel.startedSessions.count == 1 }
        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_connect_withoutApprovedExtension_asksForApprovalAndContinuesOnceApproved() async {
        tunnel.requiresApproval = true
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .needsApproval }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)

        tunnel.approve()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
    }

    func test_cancel_whileWaitingForApproval_returnsToDisconnectedAndCanConnectAgain() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        service.disconnect()

        await waitUntil { service.viewState == .disconnected }
        XCTAssertEqual(tunnel.stopCount, 1)

        tunnel.requiresApproval = false
        service.connect()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
    }

    func test_connect_whileWaitingForApproval_doesNotTimeOut() async {
        tunnel.requiresApproval = true
        let service = makeService(connectTimeout: .milliseconds(20))

        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(service.viewState, .needsApproval)
    }

    func test_connect_thatNeverFinishes_failsAsProxyUnreachableAndStopsTheTunnel() async {
        tunnel.startBehavior = .hangs
        let service = makeService(connectTimeout: .milliseconds(50))

        service.connect()

        await waitUntil { service.viewState == .failed(.proxyUnreachable) }
        await waitUntil { self.tunnel.stopCount == 1 }
    }

    func test_retry_whileTheTimedOutTunnelIsStillStopping_waitsForItBeforeStartingAgain() async {
        tunnel.startBehavior = .hangs
        tunnel.stopHangs = true
        let service = makeService(connectTimeout: .milliseconds(50))
        service.connect()
        await waitUntil { service.viewState == .failed(.proxyUnreachable) && self.tunnel.stopCount == 1 }

        tunnel.startBehavior = .connects
        service.retry()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(tunnel.startedSessions.count, 1)

        tunnel.finishStop()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
        XCTAssertEqual(tunnel.startedSessions.count, 2)
    }

    func test_logout_whileAFailedConnectionIsStillStopping_endsDisconnected() async {
        tunnel.startBehavior = .fails(VPNTunnelError.failedToStart)
        tunnel.stopHangs = true
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.stopCount == 1 }

        service.reset()
        tunnel.finishStop()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_connect_whenTheProxyConfigurationIsDenied_showsExtensionNotApproved() async {
        tunnel.startBehavior = .fails(VPNTunnelError.notApproved)
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .failed(.extensionNotApproved) }
    }

    func test_connect_whenTheTunnelFailsToStart_showsProxyUnreachable() async {
        tunnel.startBehavior = .fails(VPNTunnelError.failedToStart)
        let service = makeService()

        service.connect()

        await waitUntil { service.viewState == .failed(.proxyUnreachable) }
    }

    func test_connect_withoutSessionToken_failsAsSessionExpiredWithoutStartingTheTunnel() async {
        token = nil
        let service = makeService()

        service.connect()

        XCTAssertEqual(service.viewState, .failed(.sessionExpired))
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_connect_withoutProxyAddress_failsAsProxyUnreachable() async {
        proxyURL = nil
        let service = makeService()

        service.connect()

        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_connect_whenTheFeatureIsDisabled_doesNothing() async {
        let service = makeService(isEnabled: false)

        service.connect()

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_disconnect_whileConnected_stopsTheTunnelAndShowsDisconnected() async {
        let service = await connectedService()

        service.disconnect()

        XCTAssertEqual(service.viewState, .disconnecting)
        await waitUntil { service.viewState == .disconnected }
        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertFalse(tunnel.running)
    }

    func test_extensionReportingSessionExpired_showsTheErrorAndStopsTheTunnel() async {
        let service = await connectedService()

        tunnel.onFailure?(.sessionExpired)

        XCTAssertEqual(service.viewState, .failed(.sessionExpired))
        await waitUntil { self.tunnel.stopCount == 1 }
    }

    func test_extensionReportingProxyUnreachable_showsTheErrorAndStopsTheTunnel() async {
        let service = await connectedService()

        tunnel.onFailure?(.proxyUnreachable)

        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
        await waitUntil { self.tunnel.stopCount == 1 }
    }

    func test_extensionReportingZoneNotAllowed_showsZoneNotPermitted() async {
        let service = await connectedService()

        tunnel.onFailure?(.zoneNotAllowed)

        XCTAssertEqual(service.viewState, .failed(.zoneNotPermitted))
    }

    func test_extensionFailureWhileDisconnected_isIgnored() async {
        let service = makeService()

        tunnel.onFailure?(.sessionExpired)

        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_retry_afterAFailure_connectsAgain() async {
        let service = await connectedService()
        tunnel.onFailure?(.proxyUnreachable)
        await waitUntil { self.tunnel.stopCount == 1 }

        service.retry()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
        XCTAssertEqual(tunnel.startedSessions.count, 2)
    }

    func test_tokenRefresh_whileConnected_handsTheNewTokenToTheExtensionWithoutDisconnecting() async {
        let service = await connectedService()

        token = "token-2"
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)

        await waitUntil { self.tunnel.updatedSessions.map(\.token) == ["token-2"] }
        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, exit: nil))
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_tokenRefresh_whileConnecting_reachesTheExtensionOnceConnected() async {
        tunnel.startBehavior = .hangs
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }

        token = "token-2"
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
        try? await Task.sleep(for: .milliseconds(300))
        tunnel.finishHangingStart()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
        await waitUntil { self.tunnel.updatedSessions.map(\.token) == ["token-2"] }
    }

    func test_tokenRefresh_whileDisconnected_doesNotReachTheExtension() async {
        let service = makeService()

        token = "token-2"
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(tunnel.updatedSessions.isEmpty)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_logout_whileConnected_stopsTheTunnelAndShowsDisconnected() async {
        let service = await connectedService()

        service.reset()

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertEqual(tunnel.immediateStopCount, 1)
        XCTAssertFalse(tunnel.running)
    }

    func test_logout_whileConnecting_abandonsTheAttempt() async {
        tunnel.startBehavior = .hangs
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }

        service.reset()
        tunnel.finishHangingStart()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_quit_whileConnected_stopsTheTunnelBeforeReturning() async {
        let service = await connectedService()

        service.shutdown()

        XCTAssertEqual(tunnel.immediateStopCount, 1)
        XCTAssertFalse(tunnel.running)
    }

    func test_launch_withATunnelLeftFromAPreviousSession_stopsIt() async {
        tunnel.running = true
        let service = makeService()

        await service.disconnectLeftoverTunnel()

        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_launch_whenTheUserAlreadyStartedConnecting_leavesTheTunnelAlone() async {
        tunnel.running = true
        tunnel.startBehavior = .hangs
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }

        await service.disconnectLeftoverTunnel()

        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_launch_withoutALeftoverTunnel_stopsNothing() async {
        let service = makeService()

        await service.disconnectLeftoverTunnel()

        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_tunnelStoppingOnItsOwn_whileConnected_showsDisconnected() async {
        let service = await connectedService()

        tunnel.onUnexpectedStop?()

        XCTAssertEqual(service.viewState, .disconnected)
    }

    private func makeService(isEnabled: Bool = true, connectTimeout: Duration = .seconds(5)) -> VPNService {
        VPNService(
            tunnel: tunnel,
            isEnabled: isEnabled,
            connectTimeout: connectTimeout,
            authToken: { [unowned self] in self.token },
            proxyURL: { [unowned self] in self.proxyURL },
            now: { [connectedAt] in connectedAt }
        )
    }

    private func connectedService() async -> VPNService {
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, exit: nil) }
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

@MainActor
private final class FakeVPNTunnel: VPNTunnel {
    enum StartBehavior {
        case connects
        case fails(Error)
        case hangs
    }

    var onFailure: ((VPNTunnelFailure) -> Void)?
    var onUnexpectedStop: (() -> Void)?

    var requiresApproval = false
    var startBehavior = StartBehavior.connects
    var running = false
    var stopHangs = false
    private(set) var startedSessions: [VPNSession] = []
    private(set) var updatedSessions: [VPNSession] = []
    private(set) var stopCount = 0
    private(set) var immediateStopCount = 0

    private var pendingApproval: CheckedContinuation<Void, Error>?
    private var hangingStart: CheckedContinuation<Void, Error>?
    private var hangingStop: CheckedContinuation<Void, Never>?

    func activateExtension(onNeedsApproval: @escaping @MainActor () -> Void) async throws {
        guard requiresApproval else { return }
        onNeedsApproval()
        try await withCheckedThrowingContinuation { pendingApproval = $0 }
    }

    func approve() {
        pendingApproval?.resume()
        pendingApproval = nil
    }

    func start(_ session: VPNSession) async throws {
        startedSessions.append(session)
        switch startBehavior {
        case .connects:
            running = true
        case .fails(let error):
            throw error
        case .hangs:
            try await withCheckedThrowingContinuation { hangingStart = $0 }
            running = true
        }
    }

    func finishHangingStart() {
        hangingStart?.resume()
        hangingStart = nil
    }

    func updateSession(_ session: VPNSession) {
        updatedSessions.append(session)
    }

    func stop() async {
        stopCount += 1
        running = false
        hangingStart?.resume(throwing: CancellationError())
        hangingStart = nil
        if stopHangs {
            await withCheckedContinuation { hangingStop = $0 }
        }
    }

    func finishStop() {
        hangingStop?.resume()
        hangingStop = nil
    }

    func stopImmediately() {
        immediateStopCount += 1
        running = false
    }

    func isRunning() async -> Bool {
        running
    }
}
