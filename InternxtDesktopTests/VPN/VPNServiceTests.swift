//
//  VPNServiceTests.swift
//  InternxtDesktopTests
//
//  Created by Xavier Abad Gomez on 24/11/2026.
//

import Combine
import InternxtSwiftCore
import XCTest
@testable import Internxt

@MainActor
final class VPNServiceTests: XCTestCase {
    private let connectedAt = Date(timeIntervalSince1970: 1_800_000_000)
    private var tunnel: FakeVPNTunnel!
    private var token: String?
    private var configuration: VPNConfiguration!
    private var defaultsSuite: String!
    private var defaults: UserDefaults!
    private var vpnEntitlement: CurrentValueSubject<Bool, Never>!
    private var zones: Result<[VPNZone], Error>!
    private var zoneFetches = 0
    private var publicAddressRequests = 0
    private var publicAddress: ((URL) async throws -> PublicAddress)!
    private var holdsZones = false
    private var heldZones: CheckedContinuation<Void, Never>?

    override func setUp() async throws {
        tunnel = FakeVPNTunnel()
        token = "token-1"
        configuration = VPNConfiguration(proxyHost: "203.0.113.7", proxyPort: 8082, apiURL: URL(string: "https://vpn-api.example")!, ipAPIURL: URL(string: "https://ip.example")!)
        defaultsSuite = "VPNServiceTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuite)
        vpnEntitlement = CurrentValueSubject(false)
        zones = .success([.france])
        zoneFetches = 0
        publicAddressRequests = 0
        publicAddress = { _ in try await Task.sleep(for: .seconds(3600)); throw CancellationError() }
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: defaultsSuite)
    }

    func test_connected_showsThePublicAddressOnceFound() async {
        let frankfurt = PublicAddress(ip: "185.201.12.44", location: "Frankfurt, Hesse, Germany")
        publicAddress = { url in
            guard url == URL(string: "https://ip.example")! else { throw URLError(.badURL) }
            return frankfurt
        }
        let service = makeService()
        await startAndWaitUntilReady(service)

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, publicAddress: .found(frankfurt)) }
    }

    func test_connected_whenTheIPServiceFails_staysConnectedWithTheAddressUnavailable() async {
        publicAddress = { _ in throw URLError(.timedOut) }
        let service = makeService()
        await startAndWaitUntilReady(service)

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        await waitUntil { service.viewState == .connected(.france, since: self.connectedAt, publicAddress: .unavailable) }
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_ipServiceAnswer_isReadAsCityRegionAndCountry() throws {
        let body = Data(#"{"ip":"185.201.12.44","city":"Frankfurt","region":"Hesse","country":"Germany","org":"x"}"#.utf8)

        let info = try JSONDecoder().decode(PublicAddress.self, from: body)

        XCTAssertEqual(info, PublicAddress(ip: "185.201.12.44", location: "Frankfurt, Hesse, Germany"))
    }

    func test_ipServiceAnswerWithoutCity_skipsTheMissingParts() throws {
        let body = Data(#"{"ip":"185.201.12.44","city":"","country":"Germany"}"#.utf8)

        let info = try JSONDecoder().decode(PublicAddress.self, from: body)

        XCTAssertEqual(info.location, "Germany")
    }

    func test_ipServiceAnswerWithoutIP_isNotAnAddress() {
        let body = Data(#"{"ip":"","country":"Germany"}"#.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(PublicAddress.self, from: body))
    }

    func test_networkLost_whileConnected_showsReconnectingUntilTheSystemIsBack() async {
        let service = await connectedService()
        await waitUntil { self.publicAddressRequests == 1 }

        tunnel.systemReports(.reconnecting)
        XCTAssertEqual(service.viewState, .reconnecting(.france))

        tunnel.systemReports(.connected)

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
        await waitUntil { self.publicAddressRequests == 2 }
        XCTAssertEqual(tunnel.stopCount, 0)
    }

    func test_changingRegionWhileConnected_looksUpTheNewPublicAddress() async {
        let service = await connectedService(regions: VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: true) })
        await waitUntil { self.publicAddressRequests == 1 }

        service.select(VPNRegion(location: .germany, isAvailable: true))

        await waitUntil { self.publicAddressRequests == 2 }
        XCTAssertEqual(service.viewState, .connected(.germany, since: connectedAt, publicAddress: .loading))
    }

    func test_paidPlan_unlocksTheZonesOfThePlanAndLocksTheRest() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany, .poland])
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(availableZones(service), [.france, .germany, .poland])
        XCTAssertFalse(service.isFreePlan)
    }

    func test_planWithoutVPN_onlyAllowsFranceWithoutAskingTheBackend() async {
        zones = .success([.france, .germany])
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(availableZones(service), [.france])
        XCTAssertTrue(service.isFreePlan)
        XCTAssertEqual(zoneFetches, 0)
    }

    func test_startingUp_showsCheckingAvailabilityUntilTheZonesAreKnown() async {
        let service = makeService()

        service.start()

        XCTAssertEqual(service.viewState, .checkingAvailability)
        await waitUntil { service.viewState == .disconnected }
    }

    func test_zonesThatCannotBeLoaded_fallBackToFrance() async {
        vpnEntitlement.value = true
        zones = .failure(URLError(.badServerResponse))
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(availableZones(service), [.france])
    }

    func test_upgradingThePlan_reloadsTheZones() async {
        zones = .success([.france, .canada])
        let service = makeService()
        await startAndWaitUntilReady(service)

        vpnEntitlement.value = true

        await waitUntil { self.availableZones(service) == [.france, .canada] }
        XCTAssertFalse(service.isFreePlan)
    }

    func test_chosenRegion_isRememberedForTheNextLaunch() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany])
        let service = makeService()
        await startAndWaitUntilReady(service)

        service.select(VPNRegion(location: .germany, isAvailable: true))

        let relaunched = makeService()
        await startAndWaitUntilReady(relaunched)
        XCTAssertEqual(relaunched.selectedRegion, .germany)
    }

    func test_rememberedRegionNoLongerInThePlan_fallsBackToFrance() async {
        defaults.set("DE", forKey: "VPNService.lastRegion")
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(service.selectedRegion, .france)
    }

    func test_zonesThatCannotBeLoaded_keepTheRememberedRegionForTheNextLaunch() async {
        defaults.set("DE", forKey: "VPNService.lastRegion")
        vpnEntitlement.value = true
        zones = .failure(URLError(.timedOut))
        let service = makeService()
        await startAndWaitUntilReady(service)
        XCTAssertEqual(service.selectedRegion, .france)

        zones = .success([.france, .germany])
        let relaunched = makeService()
        await startAndWaitUntilReady(relaunched)

        XCTAssertEqual(relaunched.selectedRegion, .germany)
    }

    func test_losingTheConnectedRegion_disconnectsAndShowsZoneNotPermitted() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany])
        let service = makeService()
        await startAndWaitUntilReady(service)
        service.select(VPNRegion(location: .germany, isAvailable: true))
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        vpnEntitlement.value = false

        await waitUntil { self.tunnel.stopCount == 1 }
        tunnel.systemStops()

        XCTAssertEqual(service.viewState, .failed(.zoneNotPermitted))
        XCTAssertEqual(service.selectedRegion, .france)
        XCTAssertTrue(tunnel.updatedSessions.isEmpty)
    }

    func test_extensionReportingZoneNotAllowed_reloadsTheZones() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany])
        let service = makeService()
        await startAndWaitUntilReady(service)
        service.select(VPNRegion(location: .germany, isAvailable: true))
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        zones = .success([.france])
        tunnel.onFailure?(.zoneNotAllowed)
        tunnel.systemStops()

        await waitUntil { self.availableZones(service) == [.france] }
        XCTAssertEqual(service.selectedRegion, .france)
        XCTAssertEqual(service.viewState, .failed(.zoneNotPermitted))
    }

    func test_planZonesWithoutFrance_stillOfferFrance() async {
        vpnEntitlement.value = true
        zones = .success([.germany])
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(availableZones(service), [.france, .germany])
        XCTAssertEqual(service.selectedRegion, .france)
    }

    func test_logout_whileTheZonesAreLoading_ignoresTheirAnswer() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany])
        holdsZones = true
        let service = makeService()
        service.start()
        await waitUntil { self.zoneFetches == 1 }

        service.reset()
        heldZones?.resume()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(availableZones(service), [.france])
        XCTAssertTrue(service.isFreePlan)
    }

    func test_logout_forgetsThePlanAndTheRegionOfThePreviousUser() async {
        vpnEntitlement.value = true
        zones = .success([.france, .germany])
        let service = makeService()
        await startAndWaitUntilReady(service)
        service.select(VPNRegion(location: .germany, isAvailable: true))

        service.reset()

        XCTAssertTrue(service.isFreePlan)
        XCTAssertEqual(availableZones(service), [.france])
        XCTAssertEqual(service.selectedRegion, .france)
        XCTAssertNil(defaults.string(forKey: "VPNService.lastRegion"))
    }

    func test_connect_withApprovedExtension_endsConnectedToFranceThroughTheConfiguredProxy() async {
        let service = makeService()

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
        XCTAssertEqual(tunnel.startedSessions, [VPNSession(proxyHost: "203.0.113.7", proxyPort: 8082, location: .france, token: "token-1")])
    }

    func test_connect_showsConnectingUntilTheSystemReportsConnected() async {
        let service = makeService()

        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemReports(.connecting)

        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_connect_withoutApprovedExtension_asksForApprovalAndContinuesOnceApproved() async {
        tunnel.requiresApproval = true
        let service = makeService()

        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)

        tunnel.approve()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
    }

    func test_cancel_whileWaitingForApproval_returnsToDisconnectedAndCanConnectAgain() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        service.disconnect()

        XCTAssertEqual(service.viewState, .disconnected)
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertTrue(tunnel.startedSessions.isEmpty)

        tunnel.requiresApproval = false
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
    }

    func test_disconnect_rightAfterTheApprovalArrives_endsDisconnectedWithoutStarting() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        tunnel.approve()
        service.disconnect()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_cancel_whileWaitingForApproval_andConnectingAgainAtOnce_connects() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        tunnel.requiresApproval = false
        service.disconnect()
        service.connect()

        await waitUntil { self.tunnel.startedSessions.count == 1 }
        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_logout_whileTheSystemAsksToAllowTheConfiguration_ignoresItsAnswer() async {
        tunnel.holdsPreparation = true
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.preparedSessions.count == 1 }

        service.reset()
        tunnel.finishPreparation()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_connectingAgain_whileTheSystemStillAsksToAllowTheConfiguration_waitsForThatAnswer() async {
        tunnel.holdsPreparation = true
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.preparedSessions.count == 1 }
        service.reset()

        token = "token-2"
        service.connect()
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(tunnel.preparedSessions.count, 1)

        tunnel.finishPreparation()

        await waitUntil { self.tunnel.startedSessions.map(\.token) == ["token-2"] }
    }

    func test_connectingAgain_whileTheSystemStillAsksToAllowTheConfiguration_failsIfItIsDenied() async {
        tunnel.holdsPreparation = true
        let service = makeService()
        service.connect()
        await waitUntil { self.tunnel.preparedSessions.count == 1 }
        service.reset()
        service.connect()

        tunnel.finishPreparation(throwing: VPNTunnelError.notApproved)

        await waitUntil { service.viewState == .failed(.extensionNotApproved) }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_connect_whileWaitingForApproval_doesNotTimeOut() async {
        tunnel.requiresApproval = true
        let service = makeService(connectTimeout: .milliseconds(20))

        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(service.viewState, .needsApproval)
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
        let configuration = try VPNConfiguration(proxyURL: "http://203.0.113.7:8082", apiURL: "https://vpn-api.example", ipAPIURL: "https://ip.example")

        XCTAssertEqual(configuration, VPNConfiguration(proxyHost: "203.0.113.7", proxyPort: 8082, apiURL: URL(string: "https://vpn-api.example")!, ipAPIURL: URL(string: "https://ip.example")!))
    }

    func test_configuration_withoutProxyAddress_isMissing() {
        for value in [nil, ""] as [String?] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: value, apiURL: "https://vpn-api.example", ipAPIURL: "https://ip.example")) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .missing("VPN_PROXY_URL"))
            }
        }
    }

    func test_configuration_withoutVPNAPIAddress_isMissing() {
        for value in [nil, ""] as [String?] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: "http://203.0.113.7:8082", apiURL: value, ipAPIURL: "https://ip.example")) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .missing("VPN_API_URL"))
            }
        }
    }

    func test_configuration_withAnUnusableVPNAPIAddress_isInvalid() {
        for value in ["vpn-api.example", "not a url"] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: "http://203.0.113.7:8082", apiURL: value, ipAPIURL: "https://ip.example")) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .invalid("VPN_API_URL"))
            }
        }
    }

    func test_configuration_withoutIPServiceAddress_isMissing() {
        for value in [nil, ""] as [String?] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: "http://203.0.113.7:8082", apiURL: "https://vpn-api.example", ipAPIURL: value)) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .missing("VPN_IP_API_URL"))
            }
        }
    }

    func test_configuration_withAnUnusableIPServiceAddress_isInvalid() {
        for value in ["ip.example", "not a url"] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: "http://203.0.113.7:8082", apiURL: "https://vpn-api.example", ipAPIURL: value)) { error in
                XCTAssertEqual(error as? VPNConfigurationError, .invalid("VPN_IP_API_URL"))
            }
        }
    }

    func test_configuration_withAnUnusableProxyAddress_isInvalid() {
        for value in ["http://203.0.113.7:0", "http://203.0.113.7", "203.0.113.7:8082", "not a url"] {
            XCTAssertThrowsError(try VPNConfiguration(proxyURL: value, apiURL: "https://vpn-api.example", ipAPIURL: "https://ip.example")) { error in
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

    func test_connect_whileAnOldTunnelIsStillUp_stopsItAndStartsOnceItHasStopped() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        tunnel.systemReports(.connected)

        tunnel.approve()
        await waitUntil { self.tunnel.stopCount == 1 }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
        XCTAssertEqual(service.viewState, .connecting(.france))

        tunnel.systemStops()

        XCTAssertEqual(tunnel.startedSessions.count, 1)
        XCTAssertEqual(service.viewState, .connecting(.france))
    }

    func test_connect_whenTheOldTunnelNeverStops_failsAsProxyUnreachable() async {
        tunnel.requiresApproval = true
        let service = makeService(connectTimeout: .milliseconds(50))
        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        tunnel.systemReports(.connected)

        tunnel.approve()

        await waitUntil { service.viewState == .disconnecting }
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
        tunnel.systemStops()
        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
    }

    func test_connect_afterAbandoningAnAttempt_isNotFailedByTheAbandonedAttemptsTimeout() async {
        tunnel.requiresApproval = true
        let service = makeService(connectTimeout: .milliseconds(400))
        let firstAttempt = Date()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }
        tunnel.approve()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        service.disconnect()
        try? await Task.sleep(for: .milliseconds(200))

        tunnel.requiresApproval = false
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 2 }
        let untilAfterTheFirstTimeout = 520 - Int(Date().timeIntervalSince(firstAttempt) * 1000)
        try? await Task.sleep(for: .milliseconds(max(untilAfterTheFirstTimeout, 0)))

        XCTAssertEqual(service.viewState, .connecting(.france))
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

    func test_extensionReportingSessionExpired_showsTheErrorAndStopsTheTunnel() async {
        let service = await connectedService()

        tunnel.onFailure?(.sessionExpired)
        tunnel.systemStops()

        XCTAssertEqual(service.viewState, .failed(.sessionExpired))
        XCTAssertEqual(tunnel.stopCount, 1)
    }

    func test_extensionReportingProxyUnreachable_showsTheErrorAndStopsTheTunnel() async {
        let service = await connectedService()

        tunnel.onFailure?(.proxyUnreachable)
        tunnel.systemStops()

        XCTAssertEqual(service.viewState, .failed(.proxyUnreachable))
        XCTAssertEqual(tunnel.stopCount, 1)
    }

    func test_extensionReportingZoneNotAllowed_showsZoneNotPermitted() async {
        let service = await connectedService()

        tunnel.onFailure?(.zoneNotAllowed)
        tunnel.systemStops()

        XCTAssertEqual(service.viewState, .failed(.zoneNotPermitted))
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

        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
    }

    func test_changingLocation_whileConnected_switchesTheExtensionWithoutReconnecting() async {
        let service = await connectedService(regions: VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: true) })

        service.select(VPNRegion(location: .germany, isAvailable: true))

        XCTAssertEqual(tunnel.updatedSessions.map(\.location), [.germany])
        XCTAssertEqual(tunnel.stopCount, 0)
        XCTAssertEqual(service.viewState, .connected(.germany, since: connectedAt, publicAddress: .loading))
    }

    func test_changingLocation_whileDisconnected_onlyChangesTheSelection() async {
        let service = makeService(regions: VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: true) })

        service.select(VPNRegion(location: .germany, isAvailable: true))

        XCTAssertEqual(service.selectedRegion, .germany)
        XCTAssertTrue(tunnel.updatedSessions.isEmpty)
    }

    func test_tokenRefresh_whileConnected_handsTheNewTokenToTheExtensionWithoutDisconnecting() async {
        let service = await connectedService()

        token = "token-2"
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)

        await waitUntil { self.tunnel.updatedSessions.map(\.token) == ["token-2"] }
        XCTAssertEqual(tunnel.stopCount, 0)
        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
    }

    func test_tokenRefresh_whileWaitingForApproval_startsWithTheNewToken() async {
        tunnel.requiresApproval = true
        let service = makeService()
        await startAndWaitUntilReady(service)
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        token = "token-2"
        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
        try? await Task.sleep(for: .milliseconds(50))
        tunnel.approve()

        await waitUntil { self.tunnel.startedSessions.map(\.token) == ["token-2"] }
    }

    func test_tokenRefresh_whileDisconnected_doesNotReachTheExtension() async {
        let service = makeService()
        await startAndWaitUntilReady(service)

        NotificationCenter.default.post(name: .authTokenDidChange, object: nil)
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(tunnel.updatedSessions.isEmpty)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_logout_whileConnected_stopsTheTunnelAndEndsDisconnected() async {
        let service = await connectedService()

        service.reset()
        tunnel.systemStops()

        XCTAssertEqual(tunnel.stopCount, 1)
        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_logout_whileWaitingForApproval_neverStartsTheTunnel() async {
        tunnel.requiresApproval = true
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .needsApproval }

        service.reset()
        tunnel.approve()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(service.viewState, .disconnected)
        XCTAssertTrue(tunnel.startedSessions.isEmpty)
    }

    func test_logout_afterAFailure_clearsTheError() async {
        tunnel.prepareError = VPNTunnelError.notApproved
        let service = makeService()
        service.connect()
        await waitUntil { service.viewState == .failed(.extensionNotApproved) }

        service.reset()

        XCTAssertEqual(service.viewState, .disconnected)
    }

    func test_quit_whileConnected_stopsTheTunnel() async {
        let service = await connectedService()

        service.shutdown()

        XCTAssertEqual(tunnel.stopCount, 1)
    }

    func test_launch_withATunnelLeftFromAPreviousSession_stopsIt() async {
        tunnel.savedStatus = .connected
        let service = makeService()

        service.start()

        await waitUntil { self.tunnel.stopCount == 1 }
        XCTAssertEqual(service.viewState, .disconnecting)

        tunnel.systemStops()

        await waitUntil { service.viewState == .disconnected }
    }

    func test_launch_withoutALeftoverTunnel_stopsNothing() async {
        let service = makeService()

        await startAndWaitUntilReady(service)

        XCTAssertEqual(tunnel.stopCount, 0)
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
        connectTimeout: Duration = .seconds(5),
        regions: [VPNRegion] = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) }
    ) -> VPNService {
        VPNService(
            regions: regions,
            tunnel: tunnel,
            isEnabled: isEnabled,
            connectTimeout: connectTimeout,
            authToken: { [unowned self] in self.token },
            configuration: { [unowned self] in self.configuration },
            now: { [connectedAt] in connectedAt },
            defaults: defaults,
            vpnEntitlement: vpnEntitlement.eraseToAnyPublisher(),
            fetchZones: { [unowned self] in
                self.zoneFetches += 1
                if self.holdsZones {
                    await withCheckedContinuation { self.heldZones = $0 }
                }
                return try self.zones.get()
            },
            fetchPublicAddress: { [unowned self] url in
                self.publicAddressRequests += 1
                return try await self.publicAddress(url)
            }
        )
    }

    private func startAndWaitUntilReady(_ service: VPNService) async {
        service.start()
        await waitUntil { service.viewState == .disconnected }
    }

    private func availableZones(_ service: VPNService) -> Set<VPNZone> {
        Set(service.regions.filter(\.isAvailable).map(\.location))
    }

    private func connectedService(
        regions: [VPNRegion] = VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: $0 == .france) }
    ) async -> VPNService {
        let service = makeService(regions: regions)
        await startAndWaitUntilReady(service)
        service.connect()
        await waitUntil { self.tunnel.startedSessions.count == 1 }
        tunnel.systemConnects()
        XCTAssertEqual(service.viewState, .connected(.france, since: connectedAt, publicAddress: .loading))
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

    var savedStatus = VPNTunnelStatus.disconnected
    var requiresApproval = false
    var holdsPreparation = false
    var prepareError: Error?
    var startError: Error?
    private(set) var preparedSessions: [VPNSession] = []
    private(set) var startedSessions: [VPNSession] = []
    private(set) var updatedSessions: [VPNSession] = []
    private(set) var stopCount = 0

    private var pendingApproval: CheckedContinuation<Void, Error>?
    private var heldPreparation: CheckedContinuation<Void, Error>?

    func load() async {
        systemReports(savedStatus)
    }

    func prepare(_ session: VPNSession, onNeedsApproval: @escaping @MainActor () -> Void) async throws {
        preparedSessions.append(session)
        if let prepareError {
            throw prepareError
        }
        if requiresApproval {
            onNeedsApproval()
            try await withCheckedThrowingContinuation { pendingApproval = $0 }
        }
        if holdsPreparation {
            try await withCheckedThrowingContinuation { heldPreparation = $0 }
        }
    }

    func finishPreparation(throwing error: Error? = nil) {
        if let error {
            heldPreparation?.resume(throwing: error)
        } else {
            heldPreparation?.resume()
        }
        heldPreparation = nil
    }

    func approve() {
        pendingApproval?.resume()
        pendingApproval = nil
    }

    func start(_ session: VPNSession) throws {
        if let startError {
            throw startError
        }
        guard !status.isActive else { return }
        startedSessions.append(session)
    }

    func update(_ session: VPNSession) {
        updatedSessions.append(session)
    }

    func stop() {
        stopCount += 1
        pendingApproval?.resume(throwing: CancellationError())
        pendingApproval = nil
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
