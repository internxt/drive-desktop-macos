//
//  MailBridgeControlServer.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 14/09/2026.
//

import Foundation

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

// MARK: - Server

final class MailBridgeControlServer {

    private static let handshakeTimeout: Duration = .seconds(60)
    private static let maxFrameSize = 1 << 20

    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "MailBridge")
    private let queue = DispatchQueue(label: "com.internxt.mailbridge.control")

    private let socketURL: URL
    private var listenerDescriptor: Int32?
    private var connectionDescriptor: Int32?

    init(socketURL: URL) {
        self.socketURL = socketURL
    }

    func listen() throws {
        try queue.sync {
            guard listenerDescriptor == nil else { return }

            let path = socketURL.path
            let pathBytes = Array(path.utf8)

            var address = sockaddr_un()
            let capacity = MemoryLayout.size(ofValue: address.sun_path)
            guard pathBytes.count < capacity else {
                throw MailBridgeControlError.pathTooLong(pathBytes.count)
            }

            try FileManager.default.createDirectory(
                at: socketURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )

            unlink(path)

            let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
            guard descriptor >= 0 else {
                throw MailBridgeControlError.socketFailed("socket(): \(errnoText())")
            }

            address.sun_family = sa_family_t(AF_UNIX)
            withUnsafeMutablePointer(to: &address.sun_path) { rawPath in
                rawPath.withMemoryRebound(to: CChar.self, capacity: capacity) { destination in
                    for (index, byte) in pathBytes.enumerated() {
                        destination[index] = CChar(bitPattern: byte)
                    }
                    destination[pathBytes.count] = 0
                }
            }

            let size = socklen_t(MemoryLayout<sockaddr_un>.size)
            let bound = withUnsafePointer(to: &address) { rawAddress in
                rawAddress.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(descriptor, $0, size)
                }
            }
            guard bound == 0 else {
                close(descriptor)
                throw MailBridgeControlError.socketFailed("bind(): \(errnoText())")
            }

            guard Darwin.listen(descriptor, 1) == 0 else {
                close(descriptor)
                throw MailBridgeControlError.socketFailed("listen(): \(errnoText())")
            }

            listenerDescriptor = descriptor
            logger.info("Control socket listening at \(path)")
        }
    }

    func handshake(session: MailBridgeSession) async throws -> MailBridgeReady {
        try await withThrowingTaskGroup(of: MailBridgeReady.self) { group in
            group.addTask { [weak self] in
                guard let self else { throw MailBridgeControlError.connectionClosed }
                return try await self.runHandshake(session: session)
            }
            group.addTask { [weak self] in
                try await Task.sleep(for: Self.handshakeTimeout)
                // Closing the descriptors unblocks accept()/read() in the sibling task.
                self?.stop()
                throw MailBridgeControlError.timedOut
            }

            defer { group.cancelAll() }
            guard let ready = try await group.next() else {
                throw MailBridgeControlError.connectionClosed
            }
            return ready
        }
    }

    func stop() {
        queue.sync {
            if let connection = connectionDescriptor { close(connection) }
            if let listener = listenerDescriptor { close(listener) }
            connectionDescriptor = nil
            listenerDescriptor = nil
            unlink(socketURL.path)
        }
    }

    // MARK: - Handle Handshake

    private func runHandshake(session: MailBridgeSession) async throws -> MailBridgeReady {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [weak self] in
                guard let self else {
                    continuation.resume(throwing: MailBridgeControlError.connectionClosed)
                    return
                }
                do {
                    continuation.resume(returning: try self.performHandshake(session: session))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func performHandshake(session: MailBridgeSession) throws -> MailBridgeReady {
        guard let listener = listenerDescriptor else {
            throw MailBridgeControlError.socketFailed("the control socket is not listening")
        }

        let connection = accept(listener, nil, nil)
        guard connection >= 0 else {
            throw MailBridgeControlError.socketFailed("accept(): \(errnoText())")
        }
        connectionDescriptor = connection
        logger.info("Mail Bridge daemon connected to the control socket")

        try writeFrame(StartSessionMessage(session: session), to: connection)

        let reply = try readFrame(from: connection)
        if reply.type == "error", let code = reply.error?.code {
            throw MailBridgeControlError.daemonRefused(code: code)
        }
        guard reply.type == "ready", let ready = reply.ready else {
            throw MailBridgeControlError.malformedFrame("expected ready, got \(reply.type)")
        }

        return ready
    }

    // MARK: - Framing: 4-byte big-endian length, then one JSON value

    private struct StartSessionMessage: Encodable {
        let type = "start_session"
        let session: MailBridgeSession
    }

    private struct ControlReply: Decodable {
        let type: String
        let ready: MailBridgeReady?
        let error: ControlErrorPayload?

        struct ControlErrorPayload: Decodable { let code: String }
    }

    private func writeFrame(_ message: some Encodable, to descriptor: Int32) throws {
        let payload = try JSONEncoder().encode(message)
        guard !payload.isEmpty, payload.count <= Self.maxFrameSize else {
            throw MailBridgeControlError.malformedFrame("outgoing frame is \(payload.count) bytes")
        }

        var header = UInt32(payload.count).bigEndian
        try withUnsafeBytes(of: &header) { try writeAll(Data($0), to: descriptor) }
        try writeAll(payload, to: descriptor)
    }

    private func readFrame(from descriptor: Int32) throws -> ControlReply {
        let header = try readExactly(4, from: descriptor)
        let size = header.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        guard size > 0, size <= UInt32(Self.maxFrameSize) else {
            throw MailBridgeControlError.malformedFrame("incoming frame is \(size) bytes")
        }

        let payload = try readExactly(Int(size), from: descriptor)
        return try JSONDecoder().decode(ControlReply.self, from: payload)
    }

    private func writeAll(_ data: Data, to descriptor: Int32) throws {
        var remaining = data
        while !remaining.isEmpty {
            let written = remaining.withUnsafeBytes { buffer in
                write(descriptor, buffer.baseAddress, buffer.count)
            }
            guard written > 0 else {
                throw MailBridgeControlError.socketFailed("write(): \(errnoText())")
            }
            remaining = remaining.dropFirst(written)
        }
    }

    private func readExactly(_ count: Int, from descriptor: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: count)
        var offset = 0
        while offset < count {
            let read = buffer[offset...].withUnsafeMutableBytes { destination in
                Darwin.read(descriptor, destination.baseAddress, count - offset)
            }
            if read == 0 { throw MailBridgeControlError.connectionClosed }
            guard read > 0 else {
                throw MailBridgeControlError.socketFailed("read(): \(errnoText())")
            }
            offset += read
        }
        return Data(buffer)
    }

    private func errnoText() -> String {
        String(cString: strerror(errno))
    }
}
