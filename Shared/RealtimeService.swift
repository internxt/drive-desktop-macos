//
//  RealtimeService.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 6/9/23.
//

import Foundation
import SocketIO

class RealtimeService: ObservableObject {
    private let manager: SocketManager
    private let socket: SocketIOClient
    private var webSocketTask: URLSessionWebSocketTask?
    private var token: String
    private let onConnect: () -> Void
    private let onDisconnect: () -> Void
    private let onEvent: () -> Void
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
        self.manager = SocketManager(
            socketURL: URL(string: ConfigLoader().get().NOTIFICATIONS_URL)!,
            config: [ .forceNew(true)]
        )
        self.socket = self.manager.defaultSocket
        self.connect()
    }
    
    private func connect() {
        socket.on(clientEvent: .connect) {data, ack in
            self.isConnected = true;
            self.onConnect()
        }
        
        socket.on(clientEvent: .disconnect) {data, ack in
            self.isConnected = false;
            self.onDisconnect()
        }
        
        socket.on("event", callback: {data, _ in
            self.onEvent()
        })
        
        socket.on(clientEvent: .error) {data, ack in
            self.onDisconnect()
        }
        
        socket.connect(withPayload:["token": token])
    }
    
    public func disconnect() {
        socket.disconnect()
    }
    
}
