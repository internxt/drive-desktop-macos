//
//  AppDelegate.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import Foundation

import Cocoa
import SwiftUI
import FileProvider
import InternxtSwiftCore
import Combine
import ServiceManagement
import Sparkle
import RealmSwift

extension AppDelegate: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(true)
    }
    
    func popoverWillClose(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(false)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "App")
    let config = ConfigLoader()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    
    
    // Managers
    var windowsManager: WindowsManager! = nil
    var domainManager = FileProviderDomainManager()
    let authManager = AuthManager()
    let usageManager = UsageManager()
    let activityManager = ActivityManager()
    var globalUIManager = GlobalUIManager()
    let backupsService = BackupsService()
    let settingsManager = SettingsTabManager()
    var scheduledManager: ScheduledBackupManager!
    var popover: NSPopover?
    var statusBarItem: NSStatusItem?
    
    var listenToLoggedIn: AnyCancellable?
    var refreshTokensTimer: AnyCancellable?
    var signalEnumeratorTimer: AnyCancellable?
    
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    override init() {
        super.init()
        self.scheduledManager = ScheduledBackupManager(backupsService: backupsService)
    }
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        logger.info("App starting")
        ErrorUtils.start()
        
        
        checkVolumeAndEjectIfNeeded()
        
        self.windowsManager = WindowsManager(
            initialWindows: defaultWindows(settingsManager: settingsManager, authManager: authManager, usageManager: usageManager, backupsService: backupsService, scheduleManager: scheduledManager, updater: updaterController.updater,closeSendFeedbackWindow: closeSendFeedbackWindow, finishOrSkipOnboarding: self.finishOrSkipOnboarding),
            onWindowClose: receiveOnWindowClose
        )
        self.windowsManager.loadInitialWindows()
        if let user = authManager.user {
            Analytics.shared.identify(
                userId: user.uuid,
                email: user.email
            )
            ErrorUtils.identify(
                email:user.email,
                uuid: user.uuid
            )
        }
        
        
        self.activityManager.observeLatestActivityEntries()
        
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
                self.logger.info("User is logged in, starting session")
                self.globalUIManager.setAppStatus(.loading)
                self.loginSuccess()
            } else {
                self.destroyWidget()
                self.logger.info("User is logged out, closing session")
                self.refreshTokensTimer?.cancel()
                self.globalUIManager.setAppStatus(.loading)
                
                self.logoutSuccess()
                do {
                    try self.activityManager.clean()
                } catch {
                    error.reportToSentry()
                }
            }
            
        })
        if ConfigLoader.isDevMode == false && self.updaterController.updater.canCheckForUpdates == true {
            self.updaterController.updater.checkForUpdatesInBackground()
        }
        
        logger.info("App did start successfully")
        
    }
    
    func application(_ application: NSApplication, open urls: [URL]) {
        if let url = urls.first {
            do {
                let success = try authManager.handleSignInDeeplink(url: url)
                
                if success == true {
                    NSApp.activate(ignoringOtherApps: true)
                    self.windowsManager.closeWindow(id: "auth")
                }
            } catch {
                error.reportToSentry()
            }
            
        }
        
    }
    
    func receiveOnWindowClose(id: String) {
        if id == "onboarding" && authManager.isLoggedIn == true {
            do {
                try config.completeOnboarding()
                openFileProviderRoot()
            } catch {
                error.reportToSentry()
            }
            
        }
    }
    
    private func closeSendFeedbackWindow() {
        self.windowsManager.closeWindow(id: "send-feedback")
    }
    
    private func initializeBackups() async -> Void {
        
        
        self.logger.info("🔨 Initializing backups...")
        await backupsService.addCurrentDevice()
        self.logger.info("✅ Backups device registered")
        /**  Attempt to prevent this https://inxt.atlassian.net/browse/PB-1446 **/
        try! await Task.sleep(nanoseconds: 1_000_000_000)
        await backupsService.loadAllDevices()
        self.logger.info("✅ Backups devices loaded")
        backupsService.loadFoldersToBackup()
    }
    
    private func checkVolumeAndEjectIfNeeded() {
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
    
    private func finishOrSkipOnboarding() {
        do {
            self.openFileProviderRoot()
            self.windowsManager.closeWindow(id: "onboarding")
            try config.completeOnboarding()
        } catch {
            error.reportToSentry()
        }
        
    }
    
    private func refreshTokens() async {
        self.logger.info("Refreshing tokens...")
        do {
            try await authManager.refreshTokens()
            self.logger.info("Tokens refreshed correctly")
        } catch{
            AuthError.UnableToRefreshToken.reportToSentry()
            guard let apiClientError = error as? APIClientError else {
                return
            }
            
            let tokenIsExpired = apiClientError.statusCode == 401
            if(tokenIsExpired) {
                try? authManager.signOut()
            }
        }
    }
    
    private func startSignallingFileProvider(domainManager: NSFileProviderManager) {
        self.signalEnumeratorTimer = Timer.publish(every: 15, on:.main, in: .common)
            .autoconnect()
            .sink(
                receiveValue: {_ in
                    self.signalFileProvider(domainManager)
                })
    }
    
    private func signalFileProvider(_ domainManager: NSFileProviderManager) {
        Task {
            do {
                try await domainManager.signalEnumerator(for: .workingSet)
            } catch {
                error.reportToSentry()
                self.logger.error(["Failed to signal enumerator: ", error])
            }
        }
    }
    
    private func startTokensRefreshing() {
        self.refreshTokensTimer =  Timer.publish(every: 30, on:.main, in: .common).autoconnect().sink(
            receiveValue: {_ in
                self.checkRefreshToken()
            })
    }
    
    private func loginSuccess() {
        self.windowsManager.hideDockIcon()
        self.windowsManager.closeWindow(id: "auth")
        
        Task {
            do {
                self.startTokensRefreshing()
                await usageManager.updateUsage()
                self.logger.info("✅ Usage updated")
                try await authManager.initializeCurrentUser()
                self.logger.info("✅ Current user initialized")
                
                guard let user = self.authManager.user else {
                    throw AuthError.noUserFound
                }
                try await domainManager.initFileProviderForUser(user:user)
                guard let manager = domainManager.manager else {
                    throw FileProviderError.CannotGetFileProviderManager
                }
                
                self.startSignallingFileProvider(domainManager: manager)
                self.logger.info("Login success")
            } catch {
                self.logger.error("Failed to start the app: \(error)" )
                error.reportToSentry()
                DispatchQueue.main.async {
                    self.globalUIManager.setAppStatus(.failedToInit)
                }
            }
        }
        
        Task {
            self.logger.info("Initializing backups...")
            await self.initializeBackups()
        }
        
        self.setupWidget()
        if config.onboardingIsCompleted() == false {
            self.openOnboardingWindow()
        } else {
            self.openWidget(delayed: true)
        }
        self.scheduledManager.resumeBackupScheduler()
        
    }
    
    private func logoutSuccess() {
        self.windowsManager.displayDockIcon()
        self.openAuthWindow()
        self.windowsManager.closeAll(except: ["auth"])
        self.destroyWidget()
        self.cleanUpTimers()
        do {
            try backupsService.clean()
        } catch {
            error.reportToSentry()
        }
        
        Task {
            await domainManager.exitDomain()
        }
        
    }
    
    
    private func openAuthWindow() {
        self.windowsManager.openWindow(id: "auth")
    }
    
    @objc func openSettingsWindow() {
        self.windowsManager.openWindow(id: "settings")
    }
    
    @objc func openOnboardingWindow() {
        self.windowsManager.openWindow(id: "onboarding")
    }
    
    @objc func openSendFeedbackWindow() {
        self.windowsManager.openWindow(id: "send-feedback")
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        destroyWidget()
    }
    
    private func initPreviewMode() {
        // Nothing to do here in preview mode
    }
    
    private func removeDomain(domain: NSFileProviderDomain, completionHandler: @escaping (URL?, Error?) -> Void) {
        if #available(macOS 12.0, *) {
            NSFileProviderManager.remove(domain, mode: NSFileProviderManager.DomainRemovalMode.removeAll, completionHandler:completionHandler)
        } else {
            NSFileProviderManager.remove(domain, completionHandler: {error in
                completionHandler(nil, error)
            })
        }
    }
    
    private func destroyWidget() {
        if let statusBarItemUnwrapped = self.statusBarItem {
            NSStatusBar.system.removeStatusItem(statusBarItemUnwrapped)
            statusBarItem = nil
        }
    }
    
    private func setupWidget() {
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
            rootView: WidgetView(openFileProviderRoot: openFileProviderRoot, openSendFeedback: openSendFeedbackWindow)
                .environmentObject(self.authManager)
                .environmentObject(self.globalUIManager)
                .environmentObject(self.usageManager)
                .environmentObject(self.activityManager)
                .environmentObject(self.settingsManager)
                .environmentObject(self.backupsService)
                .environmentObject(self.domainManager)
        )
    }
    
    private func openFileProviderRoot() {
        closeWidget()
        Task{
            do {
                guard let fileProviderManager = domainManager.manager else {
                    throw FileProviderError.CannotGetFileProviderManager
                }
                let fileProviderFolderURL = try await fileProviderManager.getUserVisibleURL(for: .rootContainer)
                
                _ = fileProviderFolderURL.startAccessingSecurityScopedResource()
                NSWorkspace.shared.open(fileProviderFolderURL)
                fileProviderFolderURL.stopAccessingSecurityScopedResource()
                
            } catch {
                error.reportToSentry()
            }
            
        }
    }
    
    @objc private func togglePopover() {
        if self.statusBarItem != nil {
            if authManager.isLoggedIn == false {
                openAuthWindow()
                return
            }
            
            if let popoverUnwrapped = popover {
                if popoverUnwrapped.isShown {
                    closeWidget()
                } else {
                    openWidget()
                }
            }
            
        }
    }
    
    
    private func closeWidget() {
        globalUIManager.setWidgetIsOpen(false)
        if popover?.isShown == true {
            popover?.performClose(nil)
            popover?.contentViewController?.view.window?.resignKey()
        }
        
    }
    
    private func cleanUpTimers() {
        self.signalEnumeratorTimer?.cancel()
        self.refreshTokensTimer?.cancel()
    }
    
    
    private func openWidget(delayed: Bool = false) {
        
        func display() {
            
            if let statusBarItemButton = self.statusBarItem?.button {
                popover?.show(relativeTo: statusBarItemButton.bounds, of: statusBarItemButton, preferredEdge: NSRectEdge.minY)
                popover?.contentViewController?.view.window?.makeKey()
            }
            
            guard let manager = domainManager.manager else {
                self.logger.error("Cannot signal file provider, FileProvider manager not found")
                return
            }
            self.signalFileProvider(manager)
        }
        
        if delayed == true {
            // Prevent
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                display()
            }
        } else {
            display()
        }
        self.scheduledManager.resumeBackupScheduler()
    }
    
    private func checkRefreshToken(){
        do {
            if try authManager.needRefreshToken(){
                Task {await self.refreshTokens()}
            }
        }
        catch {
            self.logger.error("Error check refreshing token \(error)")
        }

    }
}
