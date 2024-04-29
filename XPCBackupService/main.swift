//
//  main.swift
//  XPCBackupService
//
//  Created by Richard Ascanio on 2/8/24.
//

import Foundation


let delegate = XPCBackupServiceDelegate()

let listener = NSXPCListener.service()
listener.delegate = delegate

listener.resume()
