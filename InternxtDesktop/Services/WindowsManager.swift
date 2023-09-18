//
//  WindowsManager.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 15/9/23.
//

import Foundation
import AppKit
import SwiftUI
import os.log
struct WindowConfig {
    public let view: AnyView
    public var title: String? = nil
    public var id: String = NSUUID().uuidString
    public var width: Int = 300
    public var height: Int = 300
    public var fixedToFront: Bool = true
    public var backgroundColor = Color.Surface
}

enum WindowsManagerError: Error {
    case WindowIdAlreadyExists
    case WindowIdNotFound
}

class WindowsManager:NSObject, NSWindowDelegate {
    let logger = Logger(subsystem: "com.internxt", category: "WindowsManager")

    private var windowRefs: [String:NSWindow] = [:]
    public let onWindowClose: (_ id: String) -> Void
    public let initialWindows: [WindowConfig]
    init(initialWindows: [WindowConfig], onWindowClose: @escaping (_: String) -> Void) {
        self.onWindowClose = onWindowClose
        self.initialWindows = initialWindows
    }
    
    func loadInitialWindows() {
        initialWindows.forEach{ windowConfig in
            self.createWindow(config: windowConfig)
        }
    }
    
    func displayDockIcon() {
        NSApp.setActivationPolicy(.regular)
    }
    
    func hideDockIcon() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    func createWindow(config: WindowConfig) {
        
        let windowView = config.view
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: config.width, height: config.height),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        newWindow.identifier = NSUserInterfaceItemIdentifier(config.id)
        if config.fixedToFront == true {
            newWindow.level = .floating
        }
        
        newWindow.backgroundColor = NSColor(config.backgroundColor)
        if let title = config.title {
            newWindow.title = title
        }
        
        newWindow.delegate = self
        newWindow.titlebarAppearsTransparent = true
        newWindow.toolbarStyle = .automatic
        newWindow.center()
        newWindow.isReleasedWhenClosed = false
        newWindow.setFrameAutosaveName(config.title ?? config.id)
        newWindow.contentView = NSHostingView(rootView: windowView)
        
        if windowRefs[config.id] == nil {
            windowRefs[config.id] = newWindow
        } else {
            self.logger.error("Cannot create window with id \(config.id) since it already exists, close it first")
        }
        
    }
    
    func exists(id: String) -> Bool {
        return windowRefs[id] != nil
    }
    
    func closeAll(except: [String] = []) {
        windowRefs.forEach{key, window in
            if except.contains(key) == false {
                window.close()
                windowRefs[key] = nil
            }
        }
    }
    
    func windowWillClose(_ notification: Notification) {
        let window = (notification.object as? NSWindow)
        if let id = window?.identifier {
            onWindowClose(id.rawValue)
        }
        
        
    }
    
    func openWindow(id: String) {
        if let window = windowRefs[id] {
            NSApp.activate(ignoringOtherApps: true)
            window.orderFrontRegardless()
            window.makeKeyAndOrderFront(nil)
        } else {
            self.logger.error("Cannot open window with id \(id) since it was not found, create it first")
        }
    }
    
    func closeWindow(id: String) {
        if let window = windowRefs[id] {
            window.close()
            windowRefs[id] = nil
        } else {
            self.logger.error("Cannot close window with id \(id) since it was not found, create it first")
        }
    }
}
