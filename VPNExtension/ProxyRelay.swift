import Foundation
import Network
import NetworkExtension
import os

final class ProxyRelay {
    private static let logger = Logger(subsystem: "com.internxt.vpn", category: "ProxyRelay")
    private static let connectTimeoutSeconds = 10
    private static let handshakeTimeout: DispatchTimeInterval = .seconds(15)
    private static let maximumReadLength = 65_536

    private let flow: NEAppProxyTCPFlow
    private let host: String
    private let port: Network.NWEndpoint.Port
    private let configuration: ProxyConfiguration
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "com.internxt.vpn.relay")
    private let onFinish: (ProxyRelay) -> Void

    private var handshakeBuffer = Data()
    private var isRelaying = false
    private var openDirections = 2
    private var isFinished = false

    init(
        flow: NEAppProxyTCPFlow,
        host: String,
        port: Network.NWEndpoint.Port,
        configuration: ProxyConfiguration,
        onFinish: @escaping (ProxyRelay) -> Void
    ) {
        self.flow = flow
        self.host = host
        self.port = port
        self.configuration = configuration
        self.onFinish = onFinish

        let tcp = NWProtocolTCP.Options()
        tcp.connectionTimeout = Self.connectTimeoutSeconds
        self.connection = NWConnection(
            host: .init(configuration.proxyHost),
            port: configuration.proxyPort,
            using: NWParameters(tls: nil, tcp: tcp)
        )
    }

    func start() {
        guard let tunnelRequest = CONNECTHandshake.request(host: host, port: port, region: configuration.region, token: configuration.token) else {
            Self.logger.error("Refusing a flow whose destination is not a valid host")
            queue.async { [weak self] in
                self?.finish(refusingFlow: true)
            }
            return
        }
        connection.stateUpdateHandler = { [weak self] state in
            self?.connectionChanged(to: state, sending: tunnelRequest)
        }
        connection.start(queue: queue)
        queue.asyncAfter(deadline: .now() + Self.handshakeTimeout) { [weak self] in
            guard let self, !self.isRelaying, !self.isFinished else { return }
            Self.logger.error("Proxy did not answer the tunnel request in time")
            self.finish(refusingFlow: true)
        }
    }

    func cancel() {
        queue.async { [weak self] in
            self?.finish(refusingFlow: false)
        }
    }

    private func connectionChanged(to state: NWConnection.State, sending tunnelRequest: Data) {
        switch state {
        case .ready:
            send(tunnelRequest)
        case .failed(let error), .waiting(let error):
            guard !isFinished else { return }
            Self.logger.error("Proxy connection lost: \(error.localizedDescription, privacy: .public)")
            finish(refusingFlow: !isRelaying)
        default:
            break
        }
    }

    private func send(_ tunnelRequest: Data) {
        connection.send(content: tunnelRequest, completion: .contentProcessed { [weak self] error in
            guard let self, !self.isFinished else { return }
            guard error == nil else {
                self.finish(refusingFlow: true)
                return
            }
            self.receiveTunnelResponse()
        })
    }

    private func receiveTunnelResponse() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maximumReadLength) { [weak self] data, _, isComplete, error in
            guard let self, !self.isFinished else { return }
            if let data {
                self.handshakeBuffer.append(data)
            }

            let response = CONNECTHandshake.readResponse(self.handshakeBuffer)
            switch response {
            case .incomplete where isComplete || error != nil:
                Self.logger.error("Proxy closed the connection before answering the tunnel request")
                self.finish(refusingFlow: true)
            case .incomplete:
                self.receiveTunnelResponse()
            case .established(let leftover):
                self.handshakeBuffer = Data()
                self.openFlow(delivering: leftover)
            case .sessionExpired, .zoneNotAllowed, .proxyUnavailable:
                Self.logger.error("Proxy refused the tunnel: \(String(describing: response), privacy: .public)")
                self.finish(refusingFlow: true)
            }
        }
    }

    private func openFlow(delivering leftover: Data) {
        isRelaying = true
        flow.open(withLocalEndpoint: nil) { [weak self] error in
            self?.queue.async {
                guard let self, !self.isFinished else { return }
                guard error == nil else {
                    self.finish(refusingFlow: false)
                    return
                }
                if leftover.isEmpty {
                    self.relayProxyToFlow()
                } else {
                    self.deliverToFlow(leftover, isLast: false, failed: false)
                }
                self.relayFlowToProxy()
            }
        }
    }

    private func relayFlowToProxy() {
        flow.readData { [weak self] data, error in
            self?.queue.async {
                guard let self, !self.isFinished else { return }
                guard error == nil else {
                    self.finish(refusingFlow: false)
                    return
                }
                guard let data, !data.isEmpty else {
                    self.connection.send(content: nil, contentContext: .finalMessage, isComplete: true, completion: .idempotent)
                    self.closeDirection()
                    return
                }
                self.connection.send(content: data, completion: .contentProcessed { [weak self] error in
                    guard let self, !self.isFinished else { return }
                    if let error {
                        Self.logger.error("Could not send to the proxy while relaying: \(error.localizedDescription, privacy: .public)")
                        self.abort()
                        return
                    }
                    self.relayFlowToProxy()
                })
            }
        }
    }

    private func relayProxyToFlow() {
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maximumReadLength) { [weak self] data, _, isComplete, error in
            guard let self, !self.isFinished else { return }
            if let error {
                Self.logger.error("Proxy connection failed while relaying: \(error.localizedDescription, privacy: .public)")
            }
            if let data, !data.isEmpty {
                self.deliverToFlow(data, isLast: isComplete, failed: error != nil)
            } else if error != nil {
                self.abort()
            } else if isComplete {
                self.flow.closeWriteWithError(nil)
                self.closeDirection()
            } else {
                self.relayProxyToFlow()
            }
        }
    }

    private func deliverToFlow(_ data: Data, isLast: Bool, failed: Bool) {
        flow.write(data) { [weak self] error in
            self?.queue.async {
                guard let self, !self.isFinished else { return }
                guard error == nil else {
                    self.finish(refusingFlow: false)
                    return
                }
                if failed {
                    self.abort()
                } else if isLast {
                    self.flow.closeWriteWithError(nil)
                    self.closeDirection()
                } else {
                    self.relayProxyToFlow()
                }
            }
        }
    }

    private func closeDirection() {
        openDirections -= 1
        if openDirections == 0 {
            finish(refusingFlow: false)
        }
    }

    private func abort() {
        finish(closingFlowWith: NEAppProxyFlowError(.aborted))
    }

    private func finish(refusingFlow: Bool) {
        finish(closingFlowWith: refusingFlow ? NEAppProxyFlowError(.refused) : nil)
    }

    private func finish(closingFlowWith flowError: NEAppProxyFlowError?) {
        guard !isFinished else { return }
        isFinished = true
        connection.cancel()
        flow.closeReadWithError(flowError)
        flow.closeWriteWithError(flowError)
        onFinish(self)
    }
}
