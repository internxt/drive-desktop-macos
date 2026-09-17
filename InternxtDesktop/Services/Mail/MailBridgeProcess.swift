//
//  MailBridgeProcess.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 11/09/2026.
//

import Foundation
import AppKit

enum MailBridgeProcessError: Error, LocalizedError {
    case executableNotFound
    case alreadyRunning

    var errorDescription: String? {
        switch self {
        case .executableNotFound: return "The mail-bridge executable is missing from the app bundle"
        case .alreadyRunning:     return "The mail-bridge process is already running"
        }
    }
}

/// Owns the lifetime of the embedded `mail-bridge` daemon process.
final class MailBridgeProcess: NSObject {

    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "MailBridgeProcess")

    private let queue = DispatchQueue(label: "com.internxt.mailbridge.process")
    private var process: Process?
    private var isStopping = false
    var onUnexpectedExit: ((Int32) -> Void)?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func applicationWillTerminate() {
        stop()
    }

    static var stateDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Internxt/mail-bridge", isDirectory: true)
    }

    static var controlSocketURL: URL {
        stateDirectory.appendingPathComponent("control.sock")
    }

    var isRunning: Bool {
        queue.sync { process?.isRunning ?? false }
    }

    func start(config: ConfigLoader = ConfigLoader()) throws {
        try queue.sync {
            if let running = process, running.isRunning {
                throw MailBridgeProcessError.alreadyRunning
            }

            guard let executable = Bundle.main.url(
                forResource: "mail-bridge",
                withExtension: nil,
                subdirectory: "MailBridgeResources"
            ) else {
                logger.error("mail-bridge not found in the app bundle")
                throw MailBridgeProcessError.executableNotFound
            }

            let stateDirectory = Self.stateDirectory
            try FileManager.default.createDirectory(
                at: stateDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )

            let task = Process()
            task.executableURL = executable
            task.currentDirectoryURL = stateDirectory
            task.arguments = [
                "-state-dir", stateDirectory.path,
                "-control-endpoint", Self.controlSocketURL.path
            ]
            task.environment = childEnvironment(config: config)

            task.standardOutput = pipe(scope: "stdout")
            task.standardError = pipe(scope: "stderr")

            task.terminationHandler = { [weak self] finished in
                guard let self else { return }
                self.logger.info(
                    "mail-bridge exited — reason: \(finished.terminationReason.rawValue), status: \(finished.terminationStatus)"
                )
                self.queue.async {
                    self.process = nil
                    let wasDeliberate = self.isStopping
                    if !wasDeliberate {
                        self.logger.error("mail-bridge died on its own (status \(finished.terminationStatus))")
                        self.onUnexpectedExit?(finished.terminationStatus)
                    }
                }
            }

            try task.run()
            process = task
            isStopping = false
            logger.info("mail-bridge started (pid \(task.processIdentifier))")
        }
    }

    func stop() {
        queue.sync {
            isStopping = true
            guard let running = process, running.isRunning else { return }
            logger.info("stopping mail-bridge (pid \(running.processIdentifier))")
            running.terminate()
        }
    }

    private func childEnvironment(config: ConfigLoader) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let loaded = config.get()

        if let mailAPIURL = loaded.MAIL_API_URL, !mailAPIURL.isEmpty {
            environment["MAIL_API_URL"] = mailAPIURL
        } else {
            // !TODO: We need to fail manually the daemon if the variables or any needed value is not set
            // Then, we will handle those errors here
            logger.warning("MAIL_API_URL is not set — the daemon will serve fixture mail")
        }

        if let serverPublicKey = loaded.MAIL_SERVER_PUBLIC_KEY, !serverPublicKey.isEmpty {
            environment["MAIL_SERVER_PUBLIC_KEY"] = serverPublicKey
        }

        return environment
    }

    private func pipe(scope: String) -> Pipe {
        let pipe = Pipe()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            for line in text.split(separator: "\n") where !line.isEmpty {
                self?.logger.info("[bridge/\(scope)] \(line)")
            }
        }
        return pipe
    }
}
