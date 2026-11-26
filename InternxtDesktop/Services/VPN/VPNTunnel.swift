//
//  VPNTunnel.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 24/11/2026.
//

import Foundation
import InternxtSwiftCore
import NetworkExtension
import SystemExtensions

struct VPNSession: Equatable {
    let proxyHost: String
    let proxyPort: UInt16
    var location: VPNZone
    var token: String

    var startOptions: [String: NSObject] {
        [
            VPNStartOption.proxyHost: proxyHost as NSString,
            VPNStartOption.proxyPort: NSNumber(value: proxyPort),
            VPNStartOption.region: location.rawValue as NSString,
            VPNStartOption.token: token as NSString,
        ]
    }
}

enum VPNTunnelStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case disconnecting

    init(_ status: NEVPNStatus) {
        switch status {
        case .connecting: self = .connecting
        case .connected: self = .connected
        case .reasserting: self = .reconnecting
        case .disconnecting: self = .disconnecting
        case .invalid, .disconnected: self = .disconnected
        @unknown default: self = .disconnected
        }
    }

    var isActive: Bool { self != .disconnected }
}

enum VPNTunnelError: Error {
    case notApproved
    case needsReboot
    case activationFailed
    case notPrepared
}

@MainActor
protocol VPNTunnel: AnyObject {
    var status: VPNTunnelStatus { get }
    var onStatusChange: ((VPNTunnelStatus) -> Void)? { get set }
    var onRegionSwitched: (() -> Void)? { get set }
    var onFailure: ((VPNTunnelFailure) -> Void)? { get set }

    func load() async
    func prepare(_ session: VPNSession, onNeedsApproval: @escaping @MainActor () -> Void) async throws
    func start(_ session: VPNSession) throws
    func update(_ session: VPNSession)
    func stop()
}

@MainActor
final class SystemVPNTunnel: VPNTunnel {
    private static let extensionIdentifier = "internxt.InternxtDesktop.vpn"
    private static let logger = LogService.shared.createLogger(subsystem: .VPN, category: "SystemVPNTunnel")

    private(set) var status: VPNTunnelStatus = .disconnected
    var onStatusChange: ((VPNTunnelStatus) -> Void)?
    var onRegionSwitched: (() -> Void)?
    var onFailure: ((VPNTunnelFailure) -> Void)?

    private var activation: ExtensionActivation?
    private var manager: NETransparentProxyManager?
    private var statusObserver: NSObjectProtocol?
    private var appLink: NSXPCConnection?
    private var session: VPNSession?

    nonisolated init() {}

    func load() async {
        do {
            try await loadSavedManager()
        } catch {
            Self.logger.error("Could not load the VPN configuration: \(error)")
        }
    }

    func prepare(_ session: VPNSession, onNeedsApproval: @escaping @MainActor () -> Void) async throws {
        try await activateExtension(onNeedsApproval: onNeedsApproval)
        try await loadSavedManager()

        let manager = self.manager ?? NETransparentProxyManager()
        let configuration = NETunnelProviderProtocol()
        configuration.providerBundleIdentifier = Self.extensionIdentifier
        configuration.serverAddress = session.proxyHost
        manager.protocolConfiguration = configuration
        manager.localizedDescription = "Internxt VPN"
        manager.isEnabled = true

        do {
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
        } catch let error as NEVPNError where error.code == .configurationReadWriteFailed {
            throw VPNTunnelError.notApproved
        }
        adopt(manager)
    }

    func start(_ session: VPNSession) throws {
        guard let manager else { throw VPNTunnelError.notPrepared }
        guard !VPNTunnelStatus(manager.connection.status).isActive else { return }
        try manager.connection.startVPNTunnel(options: session.startOptions)
        self.session = session
    }

    func update(_ session: VPNSession) {
        guard self.session != nil else { return }
        self.session = session
        if appLink == nil, status == .connected {
            openAppLink(sending: session)
        } else {
            send(session)
        }
    }

    func stop() {
        session = nil
        cancelPendingActivation()
        closeAppLink()
        guard let connection = manager?.connection, VPNTunnelStatus(connection.status).isActive else { return }
        connection.stopVPNTunnel()
    }

    private func loadSavedManager() async throws {
        guard manager == nil else { return }
        let managers = try await NETransparentProxyManager.loadAllFromPreferences()
        guard manager == nil, let saved = managers.first(where: Self.isOurs) else { return }
        adopt(saved)
    }

    private static func isOurs(_ manager: NETransparentProxyManager) -> Bool {
        (manager.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == extensionIdentifier
    }

    private func activateExtension(onNeedsApproval: @escaping @MainActor () -> Void) async throws {
        cancelPendingActivation()
        try await withCheckedThrowingContinuation { continuation in
            let activation = ExtensionActivation(continuation: continuation, onNeedsApproval: onNeedsApproval)
            self.activation = activation
            let request = OSSystemExtensionRequest.activationRequest(forExtensionWithIdentifier: Self.extensionIdentifier, queue: .main)
            request.delegate = activation
            OSSystemExtensionManager.shared.submitRequest(request)
        }
        activation = nil
    }

    private func cancelPendingActivation() {
        activation?.cancel()
        activation = nil
    }

    private func adopt(_ manager: NETransparentProxyManager) {
        self.manager = manager
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        statusObserver = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager.connection, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.statusChanged()
            }
        }
        statusChanged()
    }

    private func statusChanged() {
        guard let connection = manager?.connection else { return }
        let status = VPNTunnelStatus(connection.status)
        guard status != self.status else { return }
        self.status = status

        switch status {
        case .connected:
            if let session, appLink == nil {
                openAppLink(sending: session)
            }
        case .disconnected:
            session = nil
            closeAppLink()
        case .connecting, .reconnecting, .disconnecting:
            break
        }
        onStatusChange?(status)
    }

    private func openAppLink(sending session: VPNSession) {
        let extensionBundleURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/SystemExtensions/\(Self.extensionIdentifier).systemextension")
        guard let extensionBundle = Bundle(url: extensionBundleURL),
              let machServiceName = VPNExtensionXPC.machServiceName(in: extensionBundle) else {
            Self.logger.error("Could not find the extension's Mach service name")
            return
        }

        let connection = NSXPCConnection(machServiceName: machServiceName, options: [])
        connection.remoteObjectInterface = NSXPCInterface(with: VPNExtensionXPCProtocol.self)
        connection.exportedInterface = NSXPCInterface(with: VPNAppXPCProtocol.self)
        connection.exportedObject = ExtensionEvents { [weak self] reason in
            Task { @MainActor [weak self] in
                self?.extensionFailed(reason)
            }
        }
        connection.invalidationHandler = { [weak self, weak connection] in
            Self.logger.info("Connection with the extension closed")
            Task { @MainActor [weak self] in
                guard let self, let connection, self.appLink === connection else { return }
                self.appLink = nil
            }
        }
        connection.resume()
        appLink = connection
        send(session)
    }

    private func send(_ session: VPNSession) {
        let remote = appLink?.remoteObjectProxyWithErrorHandler { error in
            Self.logger.error("Could not reach the extension: \(error.localizedDescription)")
        } as? VPNExtensionXPCProtocol
        remote?.updateSession(token: session.token, region: session.location.rawValue) { [weak self] regionSwitched in
            guard regionSwitched else { return }
            Task { @MainActor [weak self] in
                self?.onRegionSwitched?()
            }
        }
    }

    private func closeAppLink() {
        appLink?.invalidate()
        appLink = nil
    }

    private func extensionFailed(_ reason: String) {
        guard session != nil, let failure = VPNTunnelFailure(rawValue: reason) else { return }
        onFailure?(failure)
    }
}

private final class ExtensionEvents: NSObject, VPNAppXPCProtocol {
    private let onFailure: (String) -> Void

    init(onFailure: @escaping (String) -> Void) {
        self.onFailure = onFailure
    }

    func didFail(reason: String) {
        onFailure(reason)
    }
}

private final class ExtensionActivation: NSObject, OSSystemExtensionRequestDelegate {
    private var continuation: CheckedContinuation<Void, Error>?
    private let onNeedsApproval: @MainActor () -> Void

    init(continuation: CheckedContinuation<Void, Error>, onNeedsApproval: @escaping @MainActor () -> Void) {
        self.continuation = continuation
        self.onNeedsApproval = onNeedsApproval
    }

    deinit {
        continuation?.resume(throwing: CancellationError())
    }

    func cancel() {
        resume(throwing: CancellationError())
    }

    func request(
        _ request: OSSystemExtensionRequest,
        actionForReplacingExtension existing: OSSystemExtensionProperties,
        withExtension ext: OSSystemExtensionProperties
    ) -> OSSystemExtensionRequest.ReplacementAction {
        .replace
    }

    func requestNeedsUserApproval(_ request: OSSystemExtensionRequest) {
        Task { @MainActor [onNeedsApproval] in
            onNeedsApproval()
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFinishWithResult result: OSSystemExtensionRequest.Result) {
        switch result {
        case .completed:
            resume(throwing: nil)
        case .willCompleteAfterReboot:
            resume(throwing: VPNTunnelError.needsReboot)
        @unknown default:
            resume(throwing: VPNTunnelError.activationFailed)
        }
    }

    func request(_ request: OSSystemExtensionRequest, didFailWithError error: Error) {
        resume(throwing: error)
    }

    private func resume(throwing error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}
