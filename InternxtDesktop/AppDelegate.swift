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
import Combine

let RESET_DOMAIN_ON_START = true


class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = Logger(subsystem: "com.internxt", category: "App")
    let config = ConfigLoader()
    var clickOutsideWindowObserver: Any?
    var popover: NSPopover!
    var statusBarItem: NSStatusItem!
    var loadedDomain: NSFileProviderDomain? = nil
    let authManager = AuthManager()
    var listenToLoggedIn: AnyCancellable?
    
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ErrorUtils.start()
        
        
        if let user = authManager.user {
            ErrorUtils.identify(
                email:user.email,
                uuid: user.uuid
            )
        }
        
        logger.info("App starting")
        
        // Load the config, or die with a fatalError
        config.load()
        
        if(isPreview) {
            // Running in preview mode
            self.initPreviewMode()
            logger.info("Preview mode did start succesfully")
            return
        }
        
        if authManager.isLoggedIn == true {
           loginSuccess()
        } else {
            displayAuthWindow()
        }
        
        logger.info("App did start successfully")
        
    }
    
    func getAuthWindow() -> NSWindow? {
        return NSApp.windows.first{$0.title == "Internxt Drive"}
    }
    
    func loginSuccess() {
        authManager.initializeCurrentUser()
        self.initFileProvider()
        setupWidget()
        self.logger.info("Login success")
        openPopover(delayed: true)
    }
    
    func logout() {
        do {
            try authManager.signOut()
            // Remove all the domains
            if let loadedDomainUnwrapped = loadedDomain {
                removeDomain(domain: loadedDomainUnwrapped, completionHandler: {_, error in
                    if let unwrappedError = error {
                        unwrappedError.reportToSentry()
                    }
                    self.loadedDomain = nil
                    self.logger.info("Domain removed correctly")
                })
            }
            displayAuthWindow()
        } catch {
            error.reportToSentry()
        }
        
    }
        
    
    func displayAuthWindow() {
        guard let window = getAuthWindow() else {
            print("No auth window found")
            return
        }
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeKey()
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        destroyWidget()
    }
    
    
    
    private func initPreviewMode() {
        // Nothing to do here in preview mode
    }
    
    private func removeDomain(domain: NSFileProviderDomain, completionHandler: @escaping (URL?, Error?) -> Void) {
        NSFileProviderManager.remove(domain, mode: NSFileProviderManager.DomainRemovalMode.removeAll, completionHandler:completionHandler)
    }
    
    private func addDomain(domain: NSFileProviderDomain) {
        
        NSFileProviderManager.add(domain) { error in
            guard let error = error else {
                self.logger.info("Domain added correctly: \(domain.displayName)")
                return
            }
            
            
            self.logger.error("Error adding file provider domain: \(error.localizedDescription)")
        }
    }
    
    private func initFileProvider() {
        let identifier = NSFileProviderDomainIdentifier(rawValue:  NSUUID().uuidString)
        let newDomain = NSFileProviderDomain(identifier: identifier, displayName: "")
        

        NSFileProviderManager.getDomainsWithCompletionHandler() { (domains, error) in
                       
            if let loadedDomain = domains.first {
                if(RESET_DOMAIN_ON_START) {
                    self.logger.info("Removing domain...")
                    NSFileProviderManager.remove(loadedDomain, mode: NSFileProviderManager.DomainRemovalMode.removeAll, completionHandler: {_,_ in
                        self.addDomain(domain: loadedDomain)
                    })
                    
                } else {
                    self.logger.info("No domain loaded, adding domain")
                    self.addDomain(domain: loadedDomain)
                }
                
            } else {
                self.logger.info("Domain is already loaded")
            }
        }
    }
    

    
    func destroyWidget() {
        if statusBarItem != nil {
            NSStatusBar.system.removeStatusItem(statusBarItem)
            statusBarItem = nil
        }
    }
    
    func setupWidget() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(self)
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
        self.popover.contentViewController = NSHostingController(rootView: WidgetView(onLogout: logout, openFileProviderRoot: openFileProviderRoot).environmentObject(self.authManager))
        
     
    }
    
    func openFileProviderRoot() {
        Task{
            do {
                guard let fileProviderFolderURL = try await NSFileProviderManager(for: loadedDomain!)?.getUserVisibleURL(for: .rootContainer) else {
                    throw FileProviderError.CannotOpenVisibleUrl
                }
                
                _ = fileProviderFolderURL.startAccessingSecurityScopedResource()
                NSWorkspace.shared.open(fileProviderFolderURL)
                fileProviderFolderURL.stopAccessingSecurityScopedResource()
                
            } catch {
                error.reportToSentry()
            }
            
        }
    }
    
    @objc func togglePopover() {
        
        if statusBarItem.button != nil {
            if authManager.isLoggedIn == false {
                displayAuthWindow()
                return
            }
            if popover.isShown {
               closePopover()
            } else {
               openPopover()
            }
        }
    }
    
    
    func closePopover() {
        popover.performClose(nil)
        popover.contentViewController?.view.window?.resignKey()
    }
    func openPopover(delayed: Bool = false) {
        func display() {
            if let button = statusBarItem.button {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: NSRectEdge.minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
        
        if delayed == true {
            // Prevent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                display()
            }
        } else {
            display()
        }
        
       
    }
   
    
}
