//
//  main.swift
//  Helper
//
//  Created by Patricio Tovar on 27/8/25.
//

import Foundation
import os

let logger = Logger(subsystem: "internxt.InternxtDesktop.cleaner.helper", category: "Default")

class ServiceDelegate: NSObject, NSXPCListenerDelegate {

    /// This method is where the NSXPCListener configures, accepts, and resumes a new incoming NSXPCConnection.
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.info("Received new connection request")

        newConnection.interruptionHandler = {
            // Handle interrupted connections here
            logger.error("Connection interrupted")
        }

        newConnection.invalidationHandler = {
            // Handle invalidated connections here
            logger.error("Connection invalidated")
        }

        // Configure the connection.
        // First, set the interface that the exported object implements.
        newConnection.exportedInterface = NSXPCInterface(with: HelperProtocol.self)

        // Next, set the object that the connection exports. All messages sent on the connection to this service will be sent to the exported object to handle. The connection retains the exported object.
        let exportedObject = Helper()
        newConnection.exportedObject = exportedObject

        // Resuming the connection allows the system to deliver more incoming messages.
        newConnection.resume()

        // Returning true from this method tells the system that you have accepted this connection. If you want to reject the connection for some reason, call invalidate() on the connection and return false.
        logger.info("Connection configured and resumed")
        return true
    }
}

// Create the delegate for the service.
let delegate = ServiceDelegate()
logger.info("Delegate created")

// Create and start the listener
let listener = NSXPCListener(machServiceName: "internxt.InternxtDesktop.cleaner.helper")
logger.info("Listener created")
listener.delegate = delegate

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()
logger.info("Listener resumed")

// Keep the main run loop running
RunLoop.current.run()
