//
//  MailBridgeControlServer.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 14/09/2026.
//

import Foundation
import NIOCore
import NIOPosix
import NIOExtras
import NIOConcurrencyHelpers

// MARK: - Wire format

struct MailBridgeSession: Encodable {
    let accountId: String
    let addresses: [String]
    let backendSession: BackendSession
    let mailClient: MailClient

    struct BackendSession: Encodable {
        let token: String
        let encryptionPrivateKey: String
        let encryptionPublicKey: String

        enum CodingKeys: String, CodingKey {
            case token
            case encryptionPrivateKey = "encryption_private_key"
            case encryptionPublicKey = "encryption_public_key"
        }
    }

    struct MailClient: Encodable {
        let username: String
        let password: String
    }

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case addresses
        case backendSession = "backend_session"
        case mailClient = "mail_client"
    }
}

struct MailBridgeReady: Decodable {
    let imapAddress: String
    let smtpAddress: String
    let startTLS: Bool

    enum CodingKeys: String, CodingKey {
        case imapAddress = "imap_address"
        case smtpAddress = "smtp_address"
        case startTLS = "starttls"
    }
}

/// What the daemon reports on its own once the handshake is done. It brackets every sync
/// that has work in it with a `syncStarted` and a `syncFinished`, so a cycle that finds
/// nothing new sends none of the three.
enum MailBridgeEvent {
    case syncStarted(total: Int)
    case syncProgress(downloaded: Int, total: Int, percent: Int)
    case syncFinished(downloaded: Int, total: Int, code: String?)
}

struct MailBridgeControlReply: Decodable {
    let type: String
    let ready: MailBridgeReady?
    let error: ControlErrorPayload?
    let started: SyncStartedPayload?
    let progress: SyncProgressPayload?
    let finished: SyncFinishedPayload?

    struct ControlErrorPayload: Decodable { let code: String }
    struct SyncStartedPayload: Decodable { let total: Int }

    struct SyncProgressPayload: Decodable {
        let downloaded: Int
        let total: Int
        /// The daemon computes it so every consumer shows the same number.
        let percent: Int
    }

    struct SyncFinishedPayload: Decodable {
        let downloaded: Int
        let total: Int
        /// Absent when the sync did all the work it set out to do.
        let code: String?
    }

    /// The sync events, and only those: `ready` is the handshake's business and an unknown
    /// type is ignored rather than treated as a failure.
    var event: MailBridgeEvent? {
        switch type {
        case "sync_started":
            return started.map { .syncStarted(total: $0.total) }
        case "sync_progress":
            return progress.map {
                .syncProgress(downloaded: $0.downloaded, total: $0.total, percent: $0.percent)
            }
        case "sync_finished":
            return finished.map {
                .syncFinished(downloaded: $0.downloaded, total: $0.total, code: $0.code)
            }
        default:
            return nil
        }
    }
}

enum MailBridgeControlError: Error, LocalizedError {
    case socketFailed(String)
    case pathTooLong(Int)
    case timedOut
    case connectionClosed
    case malformedFrame(String)
    case daemonRefused(code: String)

    var errorDescription: String? {
        switch self {
        case .socketFailed(let what):    return "Control socket error: \(what)"
        case .pathTooLong(let count):    return "The control socket path is \(count) bytes, over the ~104 the system allows"
        case .timedOut:                  return "The Mail Bridge daemon did not report ready in time"
        case .connectionClosed:          return "The Mail Bridge daemon closed the control channel"
        case .malformedFrame(let what):  return "Malformed control frame: \(what)"
        case .daemonRefused(let code):
            switch code {
            case "start_imap": return "The IMAP port is already in use"
            case "start_smtp": return "The SMTP port is already in use"
            default:           return "The Mail Bridge daemon could not start (\(code))"
            }
        }
    }
}

// MARK: - Pipeline

final class MailBridgeControlHandler: ChannelInboundHandler {
    typealias InboundIn = ByteBuffer

    private let onReply: (Result<MailBridgeControlReply, Error>) -> Void

    init(onReply: @escaping (Result<MailBridgeControlReply, Error>) -> Void) {
        self.onReply = onReply
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        var buffer = unwrapInboundIn(data)
        guard let bytes = buffer.readBytes(length: buffer.readableBytes) else { return }

        do {
            onReply(.success(try JSONDecoder().decode(MailBridgeControlReply.self, from: Data(bytes))))
        } catch {
            onReply(.failure(MailBridgeControlError.malformedFrame("\(error)")))
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        onReply(.failure(MailBridgeControlError.connectionClosed))
        context.fireChannelInactive()
    }

    func errorCaught(context: ChannelHandlerContext, error: Error) {
        onReply(.failure(error))
        context.close(promise: nil)
    }
}

enum MailBridgeControlPipeline {
    static let maxFrameSize = 1 << 20

    static func handlers(onReply: @escaping (Result<MailBridgeControlReply, Error>) -> Void) -> [ChannelHandler] {
        [
            ByteToMessageHandler(
                LengthFieldBasedFrameDecoder(lengthFieldLength: .four, lengthFieldEndianness: .big),
                maximumBufferSize: maxFrameSize
            ),
            LengthFieldPrepender(lengthFieldLength: .four, lengthFieldEndianness: .big),
            MailBridgeControlHandler(onReply: onReply),
        ]
    }
}

// MARK: - Server

final class MailBridgeControlServer {
    private static let handshakeTimeout: TimeAmount = .seconds(60)
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "MailBridgeControlServer")
    private let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    private let socketURL: URL
    private var serverChannel: Channel?
    private var connection: Channel?
    private var connected: EventLoopPromise<Channel>?
    private var timeout: Scheduled<Void>?

    private struct Shared {
        var ready: EventLoopPromise<MailBridgeReady>?
        var isStopping = false
        var onIncomingEvent: (@Sendable (MailBridgeEvent) -> Void)?
        var onChannelLost: (@Sendable () -> Void)?
    }

    private let shared = NIOLockedValueBox(Shared())

    var onIncomingEvent: (@Sendable (MailBridgeEvent) -> Void)? {
        get { shared.withLockedValue { $0.onIncomingEvent } }
        set { shared.withLockedValue { $0.onIncomingEvent = newValue } }
    }

    var onChannelLost: (@Sendable () -> Void)? {
        get { shared.withLockedValue { $0.onChannelLost } }
        set { shared.withLockedValue { $0.onChannelLost = newValue } }
    }

    private var ready: EventLoopPromise<MailBridgeReady>? {
        get { shared.withLockedValue { $0.ready } }
        set { shared.withLockedValue { $0.ready = newValue } }
    }

    init(socketURL: URL) {
        self.socketURL = socketURL
    }

    /// Creates the socket. Must run **before** the daemon is spawned: it dials once and does not retry. 
    /// Idempotent — calling it with a live socket does nothing.
    func listen() async throws {
        guard serverChannel == nil else { return }
        shared.withLockedValue { $0.isStopping = false }

        try assertPathFitsInSunPath()
        try createSocketDirectoryOwnerOnly()
        awaitDaemonOnFreshPromises()

        do {
            serverChannel = try await bindListener()
        } catch {
            let failure = MailBridgeControlError.socketFailed("bind(): \(error)")
            releaseHandshakePromises(failingAnyPending: failure)
            throw failure
        }

        logger.info("Control socket listening at \(socketURL.path)")
    }

    /// Waits for the daemon to dial in, sends it the session, and returns what it reports.
    func handshake(session: MailBridgeSession) async throws -> MailBridgeReady {
        guard let connected, let ready else {
            throw MailBridgeControlError.socketFailed("the control socket is not listening")
        }

        scheduleHandshakeTimeout(failing: connected, and: ready)
        defer { finishHandshake() }

        let channel = try await connected.futureResult.get()
        connection = channel
        logger.info("Mail Bridge daemon connected to the control socket")

        try await send(StartSessionMessage(session: session), over: channel)
        return try await ready.futureResult.get()
    }

    /// Asks the daemon to sync now. Fire-and-forget by design: it answers with its own messages on its own schedule, never with a reply to this.
    func resync() throws {
        guard let connection, connection.isActive else {
            throw MailBridgeControlError.connectionClosed
        }
        sendAndForget(ResyncMessage(), over: connection)
    }

    func stop() {
        shared.withLockedValue { $0.isStopping = true }
        finishHandshake()
        closeChannels()
        removeStaleSocketFile()
    }

    // MARK: - Opening the socket
    
    private func assertPathFitsInSunPath() throws {
        let length = socketURL.path.utf8.count
        guard length < 104 else { throw MailBridgeControlError.pathTooLong(length) }
    }
    
    private func createSocketDirectoryOwnerOnly() throws {
        try FileManager.default.createDirectory(
            at: socketURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    private func awaitDaemonOnFreshPromises() {
        let loop = group.next()
        connected = loop.makePromise(of: Channel.self)
        ready = loop.makePromise(of: MailBridgeReady.self)
    }

    private func bindListener() async throws -> Channel {
        let connected = self.connected
        let shared = self.shared

        return try await ServerBootstrap(group: group)
            .serverChannelOption(ChannelOptions.backlog, value: 1)
            .childChannelInitializer { channel in
                channel.pipeline
                    .addHandlers(MailBridgeControlPipeline.handlers { reply in
                        Self.receive(reply, using: shared)
                    })
                    .map { connected?.succeed(channel) }
            }
            .bind(unixDomainSocketPath: socketURL.path, cleanupExistingSocketFile: true)
            .get()
    }


    private static func receive(_ reply: Result<MailBridgeControlReply, Error>,
                                using shared: NIOLockedValueBox<Shared>) {
        let state = shared.withLockedValue { $0 }

        state.ready.map { Self.settleHandshake(with: reply, on: $0) }

        switch reply {
        case .success(let frame):
            frame.event.map { state.onIncomingEvent?($0) }

        case .failure:
            if state.ready == nil, !state.isStopping { state.onChannelLost?() }
        }
    }

    // MARK: - Tearing it down


    private func scheduleHandshakeTimeout(failing connected: EventLoopPromise<Channel>, and ready: EventLoopPromise<MailBridgeReady>) {
        timeout = group.next().scheduleTask(in: Self.handshakeTimeout) {
            connected.fail(MailBridgeControlError.timedOut)
            ready.fail(MailBridgeControlError.timedOut)
        }
    }

    private func cancelHandshakeTimeout() {
        timeout?.cancel()
        timeout = nil
    }

    private func finishHandshake() {
        cancelHandshakeTimeout()
        releaseHandshakePromises(failingAnyPending: .connectionClosed)
    }
    
    private func releaseHandshakePromises(failingAnyPending error: MailBridgeControlError) {
        connected?.fail(error)
        ready?.fail(error)
        connected = nil
        ready = nil
    }

    private func closeChannels() {
        connection?.close(promise: nil)
        serverChannel?.close(promise: nil)
        connection = nil
        serverChannel = nil
    }

    /// NIO removes the socket file it created on close, but one abandoned by a previous run would otherwise outlive us.
    private func removeStaleSocketFile() {
        unlink(socketURL.path)
    }

    // MARK: - Writing

    private struct StartSessionMessage: Encodable {
        let type = "start_session"
        let session: MailBridgeSession
    }

    private struct ResyncMessage: Encodable {
        let type = "resync"
    }

    private func send(_ message: some Encodable, over channel: Channel) async throws {
        let flushed = channel.eventLoop.makePromise(of: Void.self)
        enqueue(message, over: channel, flushed: flushed)
        try await flushed.futureResult.get()
    }

    private func sendAndForget(_ message: some Encodable, over channel: Channel) {
        enqueue(message, over: channel, flushed: nil)
    }

    private func enqueue(_ message: some Encodable, over channel: Channel, flushed: EventLoopPromise<Void>?) {
        do {
            let payload = try JSONEncoder().encode(message)
            var buffer = channel.allocator.buffer(capacity: payload.count)
            buffer.writeBytes(payload)
            channel.writeAndFlush(buffer, promise: flushed)
        } catch {
            flushed?.fail(error)
        }
    }

    /// The daemon answers the handshake once, so every later frame lands on a promise that is already settled. `succeed`/`fail` on a settled promise is a no-op, which is what
    /// lets the sync-event frames flow past here untouched once that read loop exists.
    private static func settleHandshake(with result: Result<MailBridgeControlReply, Error>, on promise: EventLoopPromise<MailBridgeReady>) {
        switch result {
        case .failure(let error):
            promise.fail(error)

        case .success(let reply):
            promise.completeWith(readyOrFailure(from: reply))
        }
    }

    private static func readyOrFailure(from reply: MailBridgeControlReply) -> Result<MailBridgeReady, Error> {
        if reply.type == "error", let code = reply.error?.code {
            return .failure(MailBridgeControlError.daemonRefused(code: code))
        }
        guard reply.type == "ready", let ready = reply.ready else {
            return .failure(MailBridgeControlError.malformedFrame("expected ready, got \(reply.type)"))
        }
        return .success(ready)
    }
}
