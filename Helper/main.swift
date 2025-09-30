//
//  main.swift
//  Helper
//
//  Created by Patricio Tovar on 27/8/25.
//

import Foundation
import os


let service = CleanerHelperXPCService()


// Create and start the listener
let listener = NSXPCListener(machServiceName: "internxt.InternxtDesktop.cleaner.helper")
listener.delegate = service

// Resuming the serviceListener starts this service. This method does not return.
listener.resume()

// Keep the main run loop running
RunLoop.current.run()
