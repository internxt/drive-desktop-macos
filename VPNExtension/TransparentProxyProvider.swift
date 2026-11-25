import Foundation
import Network
import NetworkExtension
import os

struct ProxyConfiguration {
    let proxyHost: String
    let proxyPort: Network.NWEndpoint.Port
    var region: String
    var token: String

    init?(options: [String: Any]?) {
        guard
            let options,
            let proxyHost = options["proxyHost"] as? String, !proxyHost.isEmpty,
            let rawProxyPort = (options["proxyPort"] as? NSNumber).flatMap({ UInt16(exactly: $0.intValue) }), rawProxyPort > 0,
            let proxyPort = Network.NWEndpoint.Port(rawValue: rawProxyPort),
            let region = options["region"] as? String, !region.isEmpty,
            let token = options["token"] as? String, !token.isEmpty
        else {
            return nil
        }
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.region = region
        self.token = token
    }
}

final class TransparentProxyProvider: NETransparentProxyProvider, VPNExtensionXPCProtocol {
    private static let logger = Logger(subsystem: "com.internxt.vpn", category: "TransparentProxyProvider")
    private static let quicPort = "443"
    private static let appConnectionDeadline: DispatchTimeInterval = .seconds(15)
    private static let failureReportInterval: TimeInterval = 5
    private static let localNetworks: [(address: String, prefix: Int)] = [
        ("10.0.0.0", 8),
        ("100.64.0.0", 10),
        ("172.16.0.0", 12),
        ("192.168.0.0", 16),
        ("169.254.0.0", 16),
        ("127.0.0.0", 8),
        ("::1", 128),
        ("fe80::", 10),
        ("fc00::", 7),
    ]

    private let lock = NSLock()
    private var configuration: ProxyConfiguration?
    private var relays: [ObjectIdentifier: ProxyRelay] = [:]
    private var lastReports: [VPNTunnelFailure: Date] = [:]

    override func startProxy(options: [String: Any]?, completionHandler: @escaping (Error?) -> Void) {
        guard let configuration = ProxyConfiguration(options: options) else {
            Self.logger.error("Proxy not started: region, token or proxy address missing")
            completionHandler(NEVPNError(.configurationInvalid))
            return
        }
        lock.withLock { self.configuration = configuration }

        setTunnelNetworkSettings(Self.networkSettings(for: configuration)) { error in
            if let error {
                Self.logger.error("Proxy network settings rejected: \(error.localizedDescription, privacy: .public)")
            } else {
                Self.logger.info("Proxy started for region \(configuration.region, privacy: .public)")
                AppLink.shared.serve(self)
                self.cancelIfAppNeverConnects()
            }
            completionHandler(error)
        }
    }

    override func stopProxy(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        let activeRelays = lock.withLock {
            configuration = nil
            defer { relays.removeAll() }
            return Array(relays.values)
        }
        activeRelays.forEach { $0.cancel() }
        AppLink.shared.stopServing(self)
        Self.logger.info("Proxy stopped (reason \(reason.rawValue, privacy: .public))")
        completionHandler()
    }

    func updateSession(token: String, region: String) {
        lock.withLock {
            configuration?.token = token
            configuration?.region = region
        }
        Self.logger.info("Session updated for region \(region, privacy: .public)")
    }

    func appWentAway() {
        guard lock.withLock({ configuration != nil }) else { return }
        Self.logger.info("Stopping the proxy because the app is gone")
        cancelProxyWithError(nil)
    }

    private func cancelIfAppNeverConnects() {
        DispatchQueue.global().asyncAfter(deadline: .now() + Self.appConnectionDeadline) { [weak self] in
            guard let self, self.lock.withLock({ self.configuration != nil }), !AppLink.shared.isAppConnected else { return }
            Self.logger.error("Stopping the proxy because the app never connected")
            self.cancelProxyWithError(nil)
        }
    }

    private func report(_ failure: VPNTunnelFailure) {
        guard AppLink.shared.isAppConnected else { return }
        let now = Date()
        let shouldReport = lock.withLock { () -> Bool in
            if let last = lastReports[failure], now.timeIntervalSince(last) < Self.failureReportInterval {
                return false
            }
            lastReports[failure] = now
            return true
        }
        guard shouldReport else { return }
        AppLink.shared.report(failure)
    }

    override func handleNewFlow(_ flow: NEAppProxyFlow) -> Bool {
        if let quicFlow = flow as? NEAppProxyUDPFlow {
            quicFlow.closeReadWithError(nil)
            quicFlow.closeWriteWithError(nil)
            return true
        }
        guard
            let tcpFlow = flow as? NEAppProxyTCPFlow,
            let endpoint = tcpFlow.remoteEndpoint as? NWHostEndpoint,
            let port = Network.NWEndpoint.Port(endpoint.port),
            let configuration = lock.withLock({ configuration })
        else {
            Self.logger.error("Refusing a flow the proxy cannot relay")
            flow.closeReadWithError(NEAppProxyFlowError(.refused))
            flow.closeWriteWithError(NEAppProxyFlowError(.refused))
            return true
        }

        let relay = ProxyRelay(
            flow: tcpFlow,
            host: tcpFlow.remoteHostname ?? endpoint.hostname,
            port: port,
            configuration: configuration,
            onFailure: { [weak self] failure in self?.report(failure) },
            onFinish: { [weak self] relay in self?.forget(relay) }
        )
        lock.withLock { relays[ObjectIdentifier(relay)] = relay }
        relay.start()
        return true
    }

    private func forget(_ relay: ProxyRelay) {
        lock.withLock { relays[ObjectIdentifier(relay)] = nil }
    }

    private static func networkSettings(for configuration: ProxyConfiguration) -> NETransparentProxyNetworkSettings {
        let settings = NETransparentProxyNetworkSettings(tunnelRemoteAddress: configuration.proxyHost)
        settings.includedNetworkRules = [
            NENetworkRule(remoteNetwork: nil, remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .TCP, direction: .outbound),
            NENetworkRule(remoteNetwork: NWHostEndpoint(hostname: "0.0.0.0", port: quicPort), remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound),
            NENetworkRule(remoteNetwork: NWHostEndpoint(hostname: "::", port: quicPort), remotePrefix: 0, localNetwork: nil, localPrefix: 0, protocol: .UDP, direction: .outbound),
        ]
        settings.excludedNetworkRules = localNetworks.map {
            NENetworkRule(destinationNetwork: NWHostEndpoint(hostname: $0.address, port: "0"), prefix: $0.prefix, protocol: .any)
        } + [proxyRule(for: configuration)]
        return settings
    }

    private static func proxyRule(for configuration: ProxyConfiguration) -> NENetworkRule {
        let proxy = NWHostEndpoint(hostname: configuration.proxyHost, port: String(configuration.proxyPort.rawValue))
        if IPv4Address(configuration.proxyHost) != nil {
            return NENetworkRule(destinationNetwork: proxy, prefix: 32, protocol: .TCP)
        }
        if IPv6Address(configuration.proxyHost) != nil {
            return NENetworkRule(destinationNetwork: proxy, prefix: 128, protocol: .TCP)
        }
        return NENetworkRule(destinationHost: proxy, protocol: .TCP)
    }
}
