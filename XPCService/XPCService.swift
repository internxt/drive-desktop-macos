//
//  XPCService.swift
//
//  Created by Robert Garcia on 2/9/23.
//

import SwiftyXPC

@main
class XPCService {
    static func main() {
        do {
            let xpcService = XPCService()

            
            let requirement: String? = nil

            let serviceListener = try XPCListener(type: .machService(name: "com.internxt.XPCService"), codeSigningRequirement: requirement)

            serviceListener.setMessageHandler(name: CommandSet.sendFileProviderItemOperationInfo, handler: xpcService.capitalizeString)

            serviceListener.activate()
            fatalError("XPCSercice should never get here")
        } catch {
            fatalError("Error while setting up XPC service: \(error)")
        }
    }

    private func capitalizeString(connection: XPCConnection, string: String) async throws -> Void {
        try connection.sendOnewayMessage(message: string, name: CommandSet.listenFileProviderItemOperationInfo)
    }
}
