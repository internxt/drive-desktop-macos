//
//  main.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 15/9/23.
//

import Foundation
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// 2
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
