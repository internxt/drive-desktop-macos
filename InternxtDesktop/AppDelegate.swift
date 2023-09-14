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
import ServiceManagement
let RESET_DOMAIN_ON_START = true

class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate, NSWindowDelegate {
    let logger = Logger(subsystem: "com.internxt", category: "App")
    let config = ConfigLoader()
    var clickOutsideWindowObserver: Any?
    var popover: NSPopover?
    var statusBarItem: NSStatusItem?
    var domainManager: DomainManager?
    var loadedDomain: NSFileProviderDomain? = nil
    let authManager = AuthManager()
    let usageManager = UsageManager()
    var listenToLoggedIn: AnyCancellable?
    var appXPCCommunicator: AppXPCCommunicator = AppXPCCommunicator.shared
    var globalUIManager: GlobalUIManager = GlobalUIManager()
    var preferencesWindow: NSWindow!
    var onboardingWindow: NSWindow!
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    
    func getFileProviderManager() throws -> NSFileProviderManager {
        guard let loadedDomain = self.loadedDomain else {
            throw FileProviderError.DomainNotLoaded
        }
        guard let manager = NSFileProviderManager(for: loadedDomain) else {
            throw FileProviderError.CannotGetFileProviderManager
        }
        return manager
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        ErrorUtils.start()
        
        checkVolumeAndEjectIfNeeded()
        
        appXPCCommunicator.test(handler: {
            self.logger.info("XPC message received")
        })
        
       
        
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
        
        self.listenToLoggedIn = authManager.$isLoggedIn.sink(receiveValue: {isLoggedIn in
            if(isLoggedIn) {
                self.globalUIManager.setAppStatus(.loading)
                self.loginSuccess()
                self.closeSwiftUIWindows()
            } else {
                self.preferencesWindow?.performClose(nil)
                self.destroyWidget()
                self.logout()
                self.openAuthWindow()
            }
        })
        
        logger.info("App did start successfully")
        
    }
    
    func closeSwiftUIWindows() {
        NSApp.windows.forEach{window in
            if window.identifier?.rawValue.contains("Auth-AppWindow") == true {
                window.close()
            }
        }
    }
    
    func getAuthWindow() -> NSWindow? {
        return NSApp.windows.first{$0.title == "Internxt Drive" && $0.identifier != nil}
    }
    
    func getSettingsWindow() -> NSWindow? {
        return NSApp.windows.first{$0.identifier?.rawValue.contains("Settings") ?? false}
    }
    
    func checkVolumeAndEjectIfNeeded() {
        do {
            let mountedVolumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: [])
            
            if let matchedVolumeURL = mountedVolumes?.first(where: {$0.lastPathComponent.contains("Internxt")}) {
                try NSWorkspace.shared.unmountAndEjectDevice(at: matchedVolumeURL)
                self.logger.info("Installer ejected correctly")
            } else {
                self.logger.info("Internxt installer was not found")
            }
        } catch {
            self.logger.error("Failed to eject the Internxt installer: \(error.localizedDescription)")
        }
    }
    
   
    
    func loginSuccess() {
        self.hideAllWindows()
        Task {
            do {
                try await authManager.initializeCurrentUser()
                // If usage fails to load, we'll let the user pass
                await usageManager.updateUsage()
                
                try await self.initFileProvider()
                self.logger.info("Login success")
            } catch {
                error.reportToSentry()
                DispatchQueue.main.async {
                    self.globalUIManager.setAppStatus(.failedToInit)
                }
               
            }
            
        }
        if config.onboardingIsCompleted() == true {
            self.setupWidget()
            self.openOnboardingWindow()
        } else {
            self.setupWidget()
            self.openPopover(delayed: true)
        }
       
    }
    
    func finishOrSkipOnboarding() {
        onboardingWindow?.performClose(nil)
        self.openFileProviderRoot()
    }
    
    func logout() {
        
        if let loadedDomainUnwrapped = loadedDomain {
            removeDomain(domain: loadedDomainUnwrapped, completionHandler: {_, error in
                if let unwrappedError = error {
                    unwrappedError.reportToSentry()
                }
                self.loadedDomain = nil
                self.logger.info("Domain removed correctly")
            })
        }
    }
        
    
    func openAuthWindow() {
        guard let window = getAuthWindow() else {
            let url = URL(string: "internxt://start-login")!
            if NSWorkspace.shared.open(url) {
                self.logger.info("Auth window not found, spawned one using a deeplink")
                NSApp.setActivationPolicy(.regular)
                if let spawnedWindow = getAuthWindow() {
                    spawnedWindow.orderFrontRegardless()
                    spawnedWindow.makeKeyAndOrderFront(nil)
                    
                }
                NSApplication.shared.activate(ignoringOtherApps: true)
                
            }
            return
        }
        
        
        NSApp.setActivationPolicy(.regular)
        window.orderFrontRegardless()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    
    func windowWillClose(_ notification: Notification) {
        // If the user closed the onboarding window we'll mark it as completed and proceed
        if (notification.object as? NSWindow)?.identifier?.rawValue == "OnboardingWindow" {
            self.onboardingWindow = nil
            finishOrSkipOnboarding()
        } else {
            hideAllWindows()
        }
        
    }
    
    @objc func openSettingsWindow() {
        self.closeSwiftUIWindows()
        if preferencesWindow == nil {
            let preferencesView = SettingsView()
                .environmentObject(authManager)
                .environmentObject(usageManager)
            preferencesWindow = NSWindow(
                contentRect: NSRect(x: 20, y: 20, width: 400, height: 290),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            preferencesWindow.level = .floating
            preferencesWindow.backgroundColor = NSColor(Color("Gray5"))
            preferencesWindow.title = "Internxt Drive"
            preferencesWindow.delegate = self
            preferencesWindow.titlebarAppearsTransparent = true
            preferencesWindow.toolbarStyle = .automatic
            preferencesWindow.center()
            preferencesWindow.isReleasedWhenClosed = false
            preferencesWindow.setFrameAutosaveName("Preferences")
            preferencesWindow.contentView = NSHostingView(rootView: preferencesView)
        }
        preferencesWindow.orderFrontRegardless()
        preferencesWindow.makeKeyAndOrderFront(nil)
    }
    
    @objc func openOnboardingWindow() {
        self.closeSwiftUIWindows()
        if onboardingWindow == nil {
            let onboardingView = OnboardingView(finishOrSkipOnboarding: finishOrSkipOnboarding)
                
            onboardingWindow = NSWindow(
                contentRect: NSRect(x: 20, y: 20, width: 800, height: 470),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            
            onboardingWindow.level = .floating
            onboardingWindow.backgroundColor = NSColor(Color("Gray5"))
            onboardingWindow.delegate = self
            onboardingWindow.titlebarAppearsTransparent = true
            onboardingWindow.toolbarStyle = .automatic
            onboardingWindow.center()
            onboardingWindow.identifier = NSUserInterfaceItemIdentifier("OnboardingWindow")
            onboardingWindow.isReleasedWhenClosed = false
            onboardingWindow.setFrameAutosaveName("Onboarding")
            onboardingWindow.contentView = NSHostingView(rootView: onboardingView)
        }
        
        self.logger.info("OPENING ONBOARDING")
        NSApplication.shared.activate(ignoringOtherApps: true)
        onboardingWindow.makeKeyAndOrderFront(nil)
        onboardingWindow.orderFrontRegardless()
    }
    
    func hideAllWindows() {
        NSApplication.shared.hide(self)
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
    
    private func addDomain(domain: NSFileProviderDomain, completionHandler: @escaping (_ error: Error?) -> Void) {
        
        NSFileProviderManager.add(domain) { error in
            guard let error = error else {
                self.loadedDomain = domain
                
                do {
                    let manager = try self.getFileProviderManager()
                        
                    self.domainManager = DomainManager(
                        domain: self.loadedDomain!,
                        uploadProgress: manager.globalProgress(for: .uploading),
                        downloadProgress: manager.globalProgress(for: .downloading)
                    )
                    
                    completionHandler(nil)
                    
                    self.logger.info("Domain added correctly: \(domain.displayName)")
                    
                } catch {
                    completionHandler(error)
                }
                
                return
            }
            
            completionHandler(error)
            self.logger.error("Error adding file provider domain: \(error.localizedDescription)")
        }
    }
    
    private func initFileProvider() async throws {
        
        return try await withCheckedThrowingContinuation {continuation in
            let identifier = NSFileProviderDomainIdentifier(rawValue:  NSUUID().uuidString)
            let newDomain = NSFileProviderDomain(identifier: identifier, displayName: "")
            
            NSFileProviderManager.getDomainsWithCompletionHandler() { (domains, error) in
                            
                let firstDomain = domains.first
                
                if let errorUnwrapped = error {
                    continuation.resume(throwing: errorUnwrapped)
                    return
                }
                
                if(RESET_DOMAIN_ON_START && firstDomain != nil) {
                    self.logger.info("Removing domain...")
                    NSFileProviderManager.remove(firstDomain!, mode: NSFileProviderManager.DomainRemovalMode.removeAll, completionHandler: {_,_ in
                        self.addDomain(domain: newDomain, completionHandler: { error in
                            if let errorUnwrapped = error {
                                continuation.resume(throwing: errorUnwrapped)
                                return
                            } else {
                                continuation.resume()
                            }
                        })
                    })
                } else {
                    self.logger.info("No domain loaded, adding domain")
                    self.addDomain(domain: newDomain, completionHandler: { error in
                        if let errorUnwrapped = error {
                            continuation.resume(throwing: errorUnwrapped)
                            return
                        } else {
                            continuation.resume()
                        }
                    })
                }
            }
        }
    }
    

    
    func destroyWidget() {
        if let statusBarItemUnwrapped = self.statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItemUnwrapped)
            statusBarItem = nil
        }
    }
    
    func setupWidget() {
        NSApp.setActivationPolicy(.accessory)
        NSApp.hide(self)
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        
        if let button = statusBarItem?.button {
            button.image = NSImage(named: "Icon")
            button.action = #selector(togglePopover)
        }
        
        self.popover = NSPopover()
        self.popover?.animates = false
        self.popover?.contentSize = NSSize(width: 300, height: 400)
        self.popover?.behavior = .transient
        self.popover?.delegate = self
        self.popover?.setValue(true, forKeyPath: "shouldHideAnchor")
        self.popover?.contentViewController = NSHostingController(
            rootView: WidgetView(onLogout: logout, openFileProviderRoot: openFileProviderRoot)
            .environmentObject(self.authManager)
            .environmentObject(self.globalUIManager)
            .environmentObject(self.usageManager)
        )
    }
    
    func openFileProviderRoot() {
        closePopover()
        Task{
            do {
                let fileProviderFolderURL = try await getFileProviderManager().getUserVisibleURL(for: .rootContainer)
                
                _ = fileProviderFolderURL.startAccessingSecurityScopedResource()
                NSWorkspace.shared.open(fileProviderFolderURL)
                fileProviderFolderURL.stopAccessingSecurityScopedResource()
                
            } catch {
                error.reportToSentry()
            }
            
        }
    }
    
    @objc func togglePopover() {
        if self.statusBarItem != nil {
            if authManager.isLoggedIn == false {
                openAuthWindow()
                return
            }
            
            if let popoverUnwrapped = popover {
                if popoverUnwrapped.isShown {
                   closePopover()
                } else {
                   openPopover()
                }
            }
            
        }
    }
    
    
    func closePopover() {
        globalUIManager.setWidgetIsOpen(false)
        popover?.performClose(nil)
        popover?.contentViewController?.view.window?.resignKey()
    }
    
    func popoverWillShow(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(true)
    }
    
    func popoverWillClose(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(false)
    }
    
    
    func openPopover(delayed: Bool = false) {
        func display() {
            
            if let statusBarItemButton = self.statusBarItem?.button {
                popover?.show(relativeTo: statusBarItemButton.bounds, of: statusBarItemButton, preferredEdge: NSRectEdge.minY)
                popover?.contentViewController?.view.window?.makeKey()
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
