import Foundation
import os

final class AppLink: NSObject, NSXPCListenerDelegate {
    static let shared = AppLink()

    private static let logger = Logger(subsystem: "com.internxt.vpn", category: "AppLink")

    private let lock = NSLock()
    private var listener: NSXPCListener?
    private var connection: NSXPCConnection?
    private weak var provider: TransparentProxyProvider?

    var isAppConnected: Bool {
        lock.withLock { connection != nil }
    }

    func serve(_ provider: TransparentProxyProvider) {
        lock.withLock {
            self.provider = provider
            guard listener == nil else { return }
            guard let machServiceName = VPNExtensionXPC.machServiceName(in: .main) else {
                Self.logger.error("No Mach service name in the extension's Info.plist")
                return
            }
            let listener = NSXPCListener(machServiceName: machServiceName)
            listener.delegate = self
            listener.resume()
            self.listener = listener
        }
    }

    func stopServing(_ provider: TransparentProxyProvider) {
        let previous = lock.withLock { () -> NSXPCConnection? in
            guard self.provider === provider else { return nil }
            self.provider = nil
            defer { connection = nil }
            return connection
        }
        previous?.invalidate()
    }

    func report(_ failure: VPNTunnelFailure) {
        let app = lock.withLock { connection }?.remoteObjectProxyWithErrorHandler { error in
            Self.logger.error("Could not notify the app: \(error.localizedDescription, privacy: .public)")
        } as? VPNAppXPCProtocol
        app?.didFail(reason: failure.rawValue)
    }

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        guard let provider = lock.withLock({ provider }) else {
            Self.logger.info("App connection refused: the proxy is not running")
            return false
        }

        newConnection.setCodeSigningRequirement(VPNExtensionXPC.appCodeSigningRequirement)
        newConnection.exportedInterface = NSXPCInterface(with: VPNExtensionXPCProtocol.self)
        newConnection.exportedObject = provider
        newConnection.remoteObjectInterface = NSXPCInterface(with: VPNAppXPCProtocol.self)
        newConnection.invalidationHandler = { [weak self, weak newConnection] in
            self?.lost(newConnection)
        }
        newConnection.interruptionHandler = { [weak self, weak newConnection] in
            self?.lost(newConnection)
        }

        let previous = lock.withLock { () -> NSXPCConnection? in
            defer { connection = newConnection }
            return connection
        }
        previous?.invalidationHandler = nil
        previous?.interruptionHandler = nil
        previous?.invalidate()

        newConnection.resume()
        Self.logger.info("App connected")
        return true
    }

    private func lost(_ lostConnection: NSXPCConnection?) {
        let provider = lock.withLock { () -> TransparentProxyProvider? in
            guard let lostConnection, lostConnection === connection else { return nil }
            connection = nil
            return self.provider
        }
        guard let provider else { return }
        Self.logger.info("App connection lost")
        provider.appWentAway()
    }
}
