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

enum MailBridgeExitReason {
    case stopped
    case unexpected(status: Int32)
}

// TODO: Use swiftlang/swift-subprocess >= 1.0.0 instead of all this once we are on
// Xcode 26 (needs Swift 6.2). Not 0.4: it does not stream a long-lived child's
// output on macOS and cancellation does not kill it.

/// Owns the lifetime of the embedded `mail-bridge` daemon process.
final class MailBridgeProcess: NSObject {
    private static let gracefulShutdownTimeout: TimeInterval = 5

    private let logger = LogService.shared.createLogger(subsystem: .Mail, category: "MailBridgeProcess")

    private let queue = DispatchQueue(label: "com.internxt.mailbridge.process")
    private var process: Process?
    private var streams: [LogStream] = []
    private var stopRequested = false
    var onTermination: (@MainActor (MailBridgeExitReason) -> Void)?

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
        waitForExit(timeout: Self.gracefulShutdownTimeout)
    }

    static var stateDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Internxt/mail-bridge", isDirectory: true)
    }

    static var controlSocketURL: URL {
        stateDirectory.appendingPathComponent("control.sock")
    }

    private static let bundledExecutable = Bundle.main.url(
        forResource: "mail-bridge",
        withExtension: nil,
        subdirectory: "MailBridgeResources"
    )

    var isRunning: Bool {
        queue.sync { process?.isRunning ?? false }
    }

    func start(config: ConfigLoader = ConfigLoader()) throws {
        try queue.sync {
            if let running = process, running.isRunning {
                throw MailBridgeProcessError.alreadyRunning
            }

            guard let executable = Self.bundledExecutable else {
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

            let stdout = LogStream(isError: false)
            let stderr = LogStream(isError: true)
            task.standardOutput = attach(stdout)
            task.standardError = attach(stderr)

            task.terminationHandler = { [weak self] finished in
                guard let self else { return }
                self.logger.info(
                    "mail-bridge exited — reason: \(finished.terminationReason.rawValue), status: \(finished.terminationStatus)"
                )
                let status = finished.terminationStatus
                self.queue.async {
                    self.releaseStreams()
                    self.process = nil
                    let wasRequested = self.stopRequested
                    self.stopRequested = false
                    let reason: MailBridgeExitReason = wasRequested ? .stopped : .unexpected(status: status)
                    Task { @MainActor [weak self] in
                        self?.onTermination?(reason)
                    }
                }
            }

            try task.run()
            process = task
            streams = [stdout, stderr]
            stopRequested = false
            logger.info("mail-bridge started (pid \(task.processIdentifier))")
        }
    }

    func stop() {
        let target: Process? = queue.sync {
            guard let running = process, running.isRunning else { return nil }
            stopRequested = true
            logger.info("stopping mail-bridge (pid \(running.processIdentifier))")
            running.terminate()
            return running
        }
        guard let target else { return }

        queue.asyncAfter(deadline: .now() + Self.gracefulShutdownTimeout) { [weak self] in
            guard let self, self.process === target, target.isRunning else { return }
            self.logger.warning("mail-bridge ignored SIGTERM, sending SIGKILL (pid \(target.processIdentifier))")
            kill(target.processIdentifier, SIGKILL)
        }
    }

    /// Blocks the caller until the daemon is gone, SIGKILLing it if it outstays `timeout`.
    private func waitForExit(timeout: TimeInterval) {
        guard let target = queue.sync(execute: { process }),
              !waitUntilExited(target, timeout: timeout) else { return }
        queue.sync {
            guard process === target, target.isRunning else { return }
            logger.warning("mail-bridge outlived its shutdown window, sending SIGKILL (pid \(target.processIdentifier))")
            kill(target.processIdentifier, SIGKILL)
        }
    }

    func wipeState() {
        queue.async { [weak self] in
            guard let self else { return }
            waitForRunningDaemonToExit()
            if !runDaemonReset() {
                removeStateDirectory()
            }
        }
    }

    private func waitForRunningDaemonToExit() {
        guard let target = process,
              !waitUntilExited(target, timeout: Self.gracefulShutdownTimeout) else { return }

        logger.warning("mail-bridge outlived its shutdown window, sending SIGKILL (pid \(target.processIdentifier))")
        kill(target.processIdentifier, SIGKILL)

        if !waitUntilExited(target, timeout: Self.gracefulShutdownTimeout) {
            logger.error("mail-bridge (pid \(target.processIdentifier)) would not exit even after SIGKILL")
        }
    }

    private func waitUntilExited(_ target: Process, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while target.isRunning {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }

    private func runDaemonReset() -> Bool {
        guard let executable = Self.bundledExecutable else {
            logger.error("mail-bridge not found in the app bundle, its keychain entries could not be cleared")
            return false
        }

        let reset = Process()
        reset.executableURL = executable
        reset.arguments = ["-reset", "-state-dir", Self.stateDirectory.path]
        let stderr = Pipe()
        reset.standardError = stderr

        do {
            try reset.run()
        } catch {
            logger.error("Could not launch mail-bridge -reset, its keychain entries could not be cleared: \(error)")
            return false
        }
        reset.waitUntilExit()

        guard reset.terminationStatus == 0 else {
            let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            logger.error(
                "mail-bridge -reset failed (status \(reset.terminationStatus)), its keychain entries could not be cleared: \(message)"
            )
            return false
        }

        logger.info("mail-bridge cleared its state directory and keychain entries")
        return true
    }

    private func removeStateDirectory() {
        do {
            try FileManager.default.removeItem(at: Self.stateDirectory)
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            return
        } catch {
            logger.error("Could not remove the Mail Bridge state directory: \(error)")
        }
    }

    private func releaseStreams() {
        for stream in streams {
            let handle = stream.pipe.fileHandleForReading
            handle.readabilityHandler = nil
            log(stream.accumulator.flush(), isError: stream.isError)
            try? handle.close()
        }
        streams = []
    }

    private func childEnvironment(config: ConfigLoader) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let loaded = config.get()

        if !loaded.MAIL_API_URL.isEmpty {
            environment["MAIL_API_URL"] = loaded.MAIL_API_URL
        } else {
            logger.warning("MAIL_API_URL is not set — the daemon will serve fixture mail")
        }

        if let serverPublicKey = loaded.MAIL_SERVER_PUBLIC_KEY, !serverPublicKey.isEmpty {
            environment["MAIL_SERVER_PUBLIC_KEY"] = serverPublicKey
        }
        
        environment["BRIDGE_TLS"] = "true"

        return environment
    }

    private func attach(_ stream: LogStream) -> Pipe {
        stream.pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData

            guard !data.isEmpty else {
                handle.readabilityHandler = nil
                self?.log(stream.accumulator.flush(), isError: stream.isError)
                return
            }

            self?.log(stream.accumulator.append(data), isError: stream.isError)
        }

        return stream.pipe
    }

    private func log(_ lines: [String], isError: Bool) {
        for line in lines {
            let daemon = DaemonLine(line)
            record(daemon.message, at: daemon.level ?? (isError ? .error : .info))
        }
    }

    private func record(_ message: String, at level: DaemonLevel) {
        switch level {
        case .info:    logger.info("[bridge] \(message)")
        case .warning: logger.warning("[bridge] \(message)")
        case .error:   logger.error("[bridge] \(message)")
        }
    }
}

private final class LogStream {
    let pipe = Pipe()
    let accumulator = LineAccumulator()
    let isError: Bool

    init(isError: Bool) {
        self.isError = isError
    }
}

private enum DaemonLevel: String {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
}

/// One line as the daemon writes it: `2026/09/18 17:19:58 [imap] INFO  synced Inbox`.
/// Its date and its level are already this side's job, so the line is taken apart into the
/// level to record it at and the part that is worth keeping. A line that does not follow
/// the shape — a Go panic, a library writing on its own — keeps no level and stays whole.
private struct DaemonLine {
    let level: DaemonLevel?
    let message: String

    init(_ line: String) {
        let fields = line.split(separator: " ", maxSplits: 4, omittingEmptySubsequences: false)

        guard fields.count == 5, let level = DaemonLevel(rawValue: String(fields[3])) else {
            self.level = nil
            self.message = line
            return
        }

        self.level = level
        self.message = "\(fields[2]) \(fields[4].trimmingCharacters(in: .whitespaces))"
    }
}

/// Reassembles whole lines out of arbitrary pipe reads: a single `availableData` can
/// end mid-line, and the daemon's next write completes it.
///
/// Locked because the readability handler and the termination handler run on different
/// queues and both reach the buffer.
private final class LineAccumulator {
    private static let maximumPendingBytes = 1 << 20

    private let lock = NSLock()
    private var pending: [UInt8] = []

    func append(_ data: Data) -> [String] {
        lock.lock()
        defer { lock.unlock() }

        pending.append(contentsOf: data)

        var lines: [String] = []
        while let newline = pending.firstIndex(of: UInt8(ascii: "\n")) {
            if let line = Self.text(from: pending[..<newline]) {
                lines.append(line)
            }
            pending.removeFirst(newline + 1)
        }

        if pending.count > Self.maximumPendingBytes {
            if let line = Self.text(from: pending[...]) {
                lines.append(line)
            }
            pending.removeAll()
        }

        return lines
    }

    /// Emits whatever is left when the stream ends without a trailing newline.
    func flush() -> [String] {
        lock.lock()
        defer { pending.removeAll(); lock.unlock() }
        guard let line = Self.text(from: pending[...]) else { return [] }
        return [line]
    }

    private static func text(from bytes: ArraySlice<UInt8>) -> String? {
        let text = String(decoding: bytes, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}
