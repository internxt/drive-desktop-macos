//
//  AppDelegate.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import Foundation

import Cocoa
import SwiftUI
import os.log
import FileProvider

@main
struct InternxtDesktopApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = Logger(subsystem: "com.internxt", category: "App")
    var clickOutsideWindowObserver: Any?
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("App starting")
        
        let identifier = NSFileProviderDomainIdentifier(rawValue:  NSUUID().uuidString)
        let domain = NSFileProviderDomain(identifier: identifier, displayName: "Drive")

        NSFileProviderManager.add(domain) { error in
            guard let error = error else {
                return
            }

            self.logger.error("Error adding file provider domain: \(error.localizedDescription)")
        }
        
        setupStatusBar()
        logger.info("App did start successfully")
        
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        NSStatusBar.system.removeStatusItem(statusBarItem)
        statusBarItem = nil
    }
    
    
    
    func setupStatusBar() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusBarItem.button {
            button.image = NSImage(named: "Icon")
            button.action = #selector(togglePopover)
        }
        
        self.popover = NSPopover()
        self.popover.animates = false
        self.popover.contentSize = NSSize(width: 300, height: 400)
        self.popover.behavior = .transient
        self.popover.setValue(true, forKeyPath: "shouldHideAnchor")
        self.popover.contentViewController = NSHostingController(rootView: ContentView())
        
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
                   [weak self] event in
                   self?.popover.performClose(event)
               }
    }
    
    @objc func togglePopover() {
        
        if let button = statusBarItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
            }
        }
    }
   
    
}
