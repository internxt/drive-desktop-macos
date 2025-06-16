//
//  RealtimeService.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 6/9/23.
//

import Foundation
import SocketIO

class RealtimeService: ObservableObject {
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    private var webSocketTask: URLSessionWebSocketTask?
    private var token: String
    private let onConnect: () -> Void
    private let onDisconnect: () -> Void
    private let onEvent: () -> Void
    private var reconnectTimer: Timer?
    private var reconnectAttempts: Int = 0
    private let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "RealtimeService")
    public var isConnected: Bool = false
    
    init(
        token: String,
        onConnect: @escaping () -> Void = {},
        onDisconnect: @escaping () -> Void = {},
        onEvent: @escaping () -> Void = {}
    ) {
        self.token = token
        self.onEvent = onEvent
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.initializeSocketManager()
    }
    
    private func initializeSocketManager() {
        self.disconnect()
        
        self.manager = SocketManager(
            socketURL: URL(string: ConfigLoader().get().NOTIFICATIONS_URL)!,
            config: [
                .forceNew(true),
                .reconnects(false),
                .connectParams(["token": token])
            ]
        )
        
        self.socket = self.manager?.defaultSocket
        self.setupSocketHandlers()
        self.connect()
    }
    
    private func setupSocketHandlers() {
        guard let socket = self.socket else { return }
        
        socket.on(clientEvent: .connect) { [weak self] data, ack in
            guard let self = self else { return }
            
            self.isConnected = true
            self.reconnectAttempts = 0
            self.logger.info("Socket.IO connected successfully")
            self.onConnect()
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] data, ack in
            guard let self = self else { return }
            
            self.isConnected = false
            self.logger.info("Socket.IO disconnected")
            self.onDisconnect()
            self.scheduleReconnect()
        }
        
        socket.on("event", callback: { [weak self] data, _ in
            guard let self = self else { return }
            self.logger.info("Received event from Socket.IO")
            self.onEvent()
        })
        
        socket.on(clientEvent: .error) { [weak self] data, ack in
            guard let self = self else { return }
            
            self.isConnected = false
            self.logger.error("Socket.IO error occurred")
            self.onDisconnect()
            self.scheduleReconnect()
        }
    }
    
    private func connect() {
        self.socket?.connect()
    }
    
    private func scheduleReconnect() {
        // Cancel any existing reconnect timer
        self.reconnectTimer?.invalidate()
        
        // Exponential backoff strategy
        let delay = min(30.0, pow(2.0, Double(reconnectAttempts)))
        self.reconnectAttempts += 1
        
        self.logger.info("Scheduling reconnect in \(delay) seconds (attempt \(reconnectAttempts))")
        
        self.reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.logger.info("Attempting to reconnect to Socket.IO")
            self.initializeSocketManager()
        }
    }
    
    public func updateToken(_ newToken: String) {
        if self.token != newToken {
            self.logger.info("Updating Socket.IO connection with new token")
            self.token = newToken
            self.initializeSocketManager()
        }
    }
    
    public func disconnect() {
        self.reconnectTimer?.invalidate()
        self.reconnectTimer = nil
        
        if self.socket != nil {
            self.socket?.removeAllHandlers()
            self.socket?.disconnect()
            self.socket = nil
        }
        
        if self.manager != nil {
            self.manager = nil
        }
        
        self.isConnected = false
    }
    
    deinit {
        self.disconnect()
    }
}
