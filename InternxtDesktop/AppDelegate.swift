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
import InternxtSwiftCore
@main
struct InternxtDesktopApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings {
            
        }
    }
}

let RESET_DOMAIN_ON_START = true
class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = Logger(subsystem: "com.internxt", category: "App")
    let config = ConfigLoader()
    var clickOutsideWindowObserver: Any?
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var domain: NSFileProviderDomain? = nil
    let authManager = AuthManager()
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("App starting")
        // Load the config, or die with a fatalError
        config.load()
        if(isPreview) {
            // Running in preview mode
            self.initPreviewMode()
            logger.info("Preview mode did start succesfully")
            return
        }
            
        
       
        if authManager.isLoggedIn == false {
            self.initNormalMode()
        } else {
            displayAuthWindow()
        }
        
        
        logger.info("App did start successfully")
        
    }
    
    func displayAuthWindow() {
        let window = NSApp.windows.first!
        window.makeKey()
        window.orderFrontRegardless()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if statusBarItem != nil {
            NSStatusBar.system.removeStatusItem(statusBarItem)
            statusBarItem = nil
        }
        
    }
    
    
    private func initPreviewMode() {
        // Nothing to do here in preview mode
    }
    
    private func addDomain(domain: NSFileProviderDomain) {
        NSFileProviderManager.add(domain) { error in
            guard let error = error else {
                self.logger.info("Domain added correctly: \(self.domain!.displayName)")
                return
            }
            
            self.logger.error("Error adding file provider domain: \(error.localizedDescription)")
        }
    }
    
    private func initDevMode() {
        self.logger.info("Initializing dev mode")
        
        let loadedConfig = config.get()
        
        do {
            guard let authToken = loadedConfig.AUTH_TOKEN else {
                return
            }
            
            try config.setAuthToken(authToken: authToken)
            self.logger.info("Loaded auth token from env")
            guard let legacyAuthToken = loadedConfig.LEGACY_AUTH_TOKEN else {
                return
            }
            
            try config.setLegacyAuthToken(legacyAuthToken: legacyAuthToken)
            self.logger.info("Loaded legacy auth token from env")
        } catch {
            
            self.logger.error("Failed to load dev mode: \(error)")
        }
        
    }
    
    private func initNormalMode() {
        self.initDevMode()
        let identifier = NSFileProviderDomainIdentifier(rawValue:  NSUUID().uuidString)
        self.domain = NSFileProviderDomain(identifier: identifier, displayName: "Internxt Drive")
        
        NSFileProviderManager.getDomainsWithCompletionHandler() { (domains, error) in
                       
            let loadedDomain = domains.first
            if(loadedDomain == nil) {
                self.logger.info("No domain loaded, adding domain")
                self.addDomain(domain: self.domain!)
            } else {
                if(RESET_DOMAIN_ON_START) {
                    self.logger.info("Removing domain...")
                    NSFileProviderManager.remove(loadedDomain!, mode: NSFileProviderManager.DomainRemovalMode.removeAll, completionHandler: {_,_ in
                        self.addDomain(domain: self.domain!)
                    })
                    
                } else {
                    self.logger.info("Domain is already loaded")
                    self.signalForIdentifier()
                }
            }
        }
        
        signalEnumeratorPeriodically()
        setupStatusBar()
   
    }
    func signalForIdentifier() {
        
        if domain == nil {
            self.logger.error("Cannot signal, domain not found")
            return
        }
        
        guard let manager = NSFileProviderManager(for: domain!) else {
            self.logger.error("Failed to get FileProviderManager")
            return
        }
        
        
        manager.signalEnumerator(for: NSFileProviderItemIdentifier.rootContainer, completionHandler: {(error) in
            
            if error != nil {
                self.logger.error("Failed to signal: \(error)")
            }
            self.logger.info("Container signaled correctly")
        })
    }
    
    /// Signal the FileProvider extension periodically to trigger
    /// root container refresh, this should be used in dev mode only,
    /// in production we should go for a realtime solution
    func signalEnumeratorPeriodically() {
        Timer.scheduledTimer(withTimeInterval: 15, repeats: true, block: { _ in
            self.signalForIdentifier()
        })
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
        self.popover.contentViewController = NSHostingController(rootView: ContentView().environmentObject(self.authManager))
        
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
