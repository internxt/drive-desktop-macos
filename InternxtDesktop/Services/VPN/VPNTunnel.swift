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
    let location: VPNZone
    let token: String

    var startOptions: [String: NSObject] {
        [
            "proxyHost": proxyHost as NSString,
            "proxyPort": NSNumber(value: proxyPort),
            "region": location.rawValue as NSString,
            "token": token as NSString,
        ]
    }

    func refreshed(with token: String) -> VPNSession {
        VPNSession(proxyHost: proxyHost, proxyPort: proxyPort, location: location, token: token)
    }
}

enum VPNTunnelError: Error {
    case notApproved
    case needsReboot
    case failedToStart
}

@MainActor
protocol VPNTunnel: AnyObject {
    var onFailure: ((VPNTunnelFailure) -> Void)? { get set }
    var onUnexpectedStop: (() -> Void)? { get set }

    func activateExtension(onNeedsApproval: @escaping @MainActor () -> Void) async throws
    func start(_ session: VPNSession) async throws
    func updateSession(_ session: VPNSession)
    func stop() async
    func stopImmediately()
    func isRunning() async -> Bool
}

@MainActor
final class SystemVPNTunnel: VPNTunnel {
    private static let extensionIdentifier = "internxt.InternxtDesktop.vpn"
    private static let stopTimeout: Duration = .seconds(5)
    private static let logger = LogService.shared.createLogger(subsystem: .VPN, category: "SystemVPNTunnel")

    var onFailure: ((VPNTunnelFailure) -> Void)?
    var onUnexpectedStop: (() -> Void)?

    private var activation: ExtensionActivation?
    private var manager: NETransparentProxyManager?
    private var statusObserver: NSObjectProtocol?
    private var appLink: NSXPCConnection?
    private var session: VPNSession?
    private var pendingStart: CheckedContinuation<Void, Error>?
    private var startHasProgressed = false
    private var pendingStops: [CheckedContinuation<Void, Never>] = []
    private var stopDeadline: Task<Void, Never>?

    nonisolated init() {}

    func activateExtension(onNeedsApproval: @escaping @MainActor () -> Void) async throws {
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

    func start(_ session: VPNSession) async throws {
        let manager = try await loadManager() ?? NETransparentProxyManager()
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

        self.manager = manager
        observeStatus(of: manager.connection)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            pendingStart = continuation
            startHasProgressed = false
            do {
                try manager.connection.startVPNTunnel(options: session.startOptions)
            } catch {
                resumeStart(throwing: error)
            }
        }

        self.session = session
        openAppLink(sending: session)
    }

    func updateSession(_ session: VPNSession) {
        guard self.session != nil else { return }
        self.session = session
        send(session)
    }

    func stop() async {
        session = nil
        cancelPendingActivation()
        resumeStart(throwing: CancellationError())
        guard let connection = try? await loadManager()?.connection, connection.status.isActive else {
            closeAppLink()
            return
        }
        observeStatus(of: connection)

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            pendingStops.append(continuation)
            connection.stopVPNTunnel()
            stopDeadline?.cancel()
            stopDeadline = Task { [weak self] in
                try? await Task.sleep(for: Self.stopTimeout)
                guard !Task.isCancelled else { return }
                self?.resumeStops()
            }
        }
        closeAppLink()
    }

    func stopImmediately() {
        session = nil
        cancelPendingActivation()
        manager?.connection.stopVPNTunnel()
        closeAppLink()
    }

    func isRunning() async -> Bool {
        guard let manager = try? await loadManager() else { return false }
        return manager.connection.status.isActive
    }

    private func cancelPendingActivation() {
        activation?.cancel()
        activation = nil
    }

    private func loadManager() async throws -> NETransparentProxyManager? {
        if let manager { return manager }
        let managers = try await NETransparentProxyManager.loadAllFromPreferences()
        manager = managers.first {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == Self.extensionIdentifier
        }
        return manager
    }

    private func observeStatus(of connection: NEVPNConnection) {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        statusObserver = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: connection, queue: .main) { [weak self] notification in
            guard let status = (notification.object as? NEVPNConnection)?.status else { return }
            Task { @MainActor [weak self] in
                self?.statusChanged(status)
            }
        }
    }

    private func statusChanged(_ status: NEVPNStatus) {
        switch status {
        case .connecting, .reasserting:
            startHasProgressed = true
        case .connected:
            resumeStart(throwing: nil)
        case .disconnected, .invalid:
            resumeStops()
            if pendingStart != nil {
                if startHasProgressed {
                    resumeStart(throwing: VPNTunnelError.failedToStart)
                }
            } else if session != nil {
                Self.logger.info("The tunnel stopped without the app asking")
                session = nil
                closeAppLink()
                onUnexpectedStop?()
            }
        case .disconnecting:
            break
        @unknown default:
            break
        }
    }

    private func resumeStart(throwing error: Error?) {
        guard let pendingStart else { return }
        self.pendingStart = nil
        if let error {
            pendingStart.resume(throwing: error)
        } else {
            pendingStart.resume()
        }
    }

    private func resumeStops() {
        stopDeadline?.cancel()
        stopDeadline = nil
        let stops = pendingStops
        pendingStops = []
        stops.forEach { $0.resume() }
    }

    private func openAppLink(sending session: VPNSession) {
        closeAppLink()
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
        connection.invalidationHandler = {
            Self.logger.info("Connection with the extension closed")
        }
        connection.resume()
        appLink = connection
        send(session)
    }

    private func send(_ session: VPNSession) {
        let remote = appLink?.remoteObjectProxyWithErrorHandler { error in
            Self.logger.error("Could not reach the extension: \(error.localizedDescription)")
        } as? VPNExtensionXPCProtocol
        remote?.updateSession(token: session.token, region: session.location.rawValue)
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

private extension NEVPNStatus {
    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reasserting, .disconnecting:
            return true
        case .invalid, .disconnected:
            return false
        @unknown default:
            return false
        }
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
            resume(throwing: VPNTunnelError.failedToStart)
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
