//
//  AppXPCCommunicator.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 2/9/23.
//

import Foundation
import SwiftyXPC
import os

struct Demo: Codable {
    public let testValue: String
    
    init(testValue: String) {
        self.testValue = testValue
    }
}
class AppXPCCommunicator {
    static let shared = try! AppXPCCommunicator()
    
    private let connection: XPCConnection
    
    @Published var messageSendInProgress = false
    
    
    public func sendTest(value: String) async throws {
        try await self.connection.sendMessage(
            name: CommandSet.sendFileProviderItemOperationInfo,
            request: String(value)
        )
    }
    
    public func test(handler: @escaping () -> Void) {
        func handleMessage(_ connection: XPCConnection, _ payload: String) async throws -> Void {
            print(payload)
        }
        
        self.connection.setMessageHandler(
            name: CommandSet.listenFileProviderItemOperationInfo,
            handler: handleMessage
        )
        
    }
    
    private init() throws {
        let connection = try XPCConnection(type: .remoteService(bundleID: "com.internxt.XPCService"))

        let logger = Logger()

        connection.errorHandler = { _, error in
                logger.error("The connection to the Internxt XPC service received an error:\(error.localizedDescription)")
        }
        connection.resume()
        self.connection = connection
        logger.info("✅ AppXPCCommunicator is ready")
    }
    
    
}
