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
import PushKit
import UserNotifications

extension AppDelegate: NSPopoverDelegate {
    func popoverWillShow(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(true)
    }
    
    func popoverWillClose(_ notification: Notification) {
        globalUIManager.setWidgetIsOpen(false)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate , PKPushRegistryDelegate {
    let logger = LogService.shared.createLogger(subsystem: .InternxtDesktop, category: "App")
    let config = ConfigLoader()
    private let updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private let DEVICE_TYPE = "macos"
    var pushRegistry: PKPushRegistry!
    private let AUTH_TOKEN_KEY = "AuthToken"
    
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
    var realtime: RealtimeService?
    var popover: NSPopover?
    var statusBarItem: NSStatusItem?
    
    var listenToLoggedIn: AnyCancellable?
    var refreshTokensTimer: AnyCancellable?
    var signalEnumeratorTimer: AnyCancellable?
    var usageUpdateDebouncer = Debouncer(delay: 15.0)
    private let driveNewAPI: DriveAPI = APIFactory.DriveNew
    
    var isPreview: Bool {
        return ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    override init() {
        super.init()
        self.scheduledManager = ScheduledBackupManager(backupsService: backupsService)
        self.requestNotificationsPermissions()
        if let authToken = config.getAuthToken() {
            self.realtime = RealtimeService.init(
                token: authToken,
                onConnect: {},
                onDisconnect: {},
                onEvent: {
                    Task {try? await self.domainManager.manager?.signalEnumerator(for: .workingSet)}
                }
            )
        }
        
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
        pushRegistry = PKPushRegistry(queue: nil)
        pushRegistry.delegate = self
        pushRegistry.desiredPushTypes = [.fileProvider]
        
    }
    
    
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didUpdate credentials: PKPushCredentials,
        for type: PKPushType
    ){
        logger.info("📍 Got Device token for push notifications from AppDelegate")
        let deviceToken = credentials.token

        
        
        guard let newAuthToken = config.getAuthToken() else{
            logger.error("Cannot get AuthToken")
            return
        }
        let deviceTokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        
        Task {
            do {
                let result = try await driveNewAPI.registerPushDeviceToken(currentAuthToken: newAuthToken, deviceToken: deviceTokenString, type: DEVICE_TYPE)
                logger.info(["📍 Push device token \(deviceTokenString) registered", result])
                
            }catch{
                logger.error(["Cannot sync token", error])
            }
        }
    }
    
    func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        
        guard type == .fileProvider else {
            completion()
            return
        }
        self.logger.info("✅ Notification received")
        enumerateAllDomains()


        completion()
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

                
                self.logger.info("Login success")
                
                guard let workspaces = self.authManager.availableWorkspaces else {
                    return
                }
               try await domainManager.initFileProviderForUserWorkspace(user: user, workspaces: workspaces)
                
                self.logger.info("Workspaces setted correctly")
            } catch {
                self.logger.error("Failed to start the app: \(error)" )
                error.reportToSentry()
                DispatchQueue.main.async {
                    self.globalUIManager.setAppStatus(.failedToInit)
                }
            }
        }
        
        Task {
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
       
        usageUpdateDebouncer.debounce { [weak self] in
            self?.updateUsage()
        }
    }
    
    private func checkRefreshToken(){
        do {
            let refreshTokenCheckResult = try authManager.needRefreshToken()
            if refreshTokenCheckResult.needsRefresh {
                Task {await self.refreshTokens()}
            }
        }
        catch {
            self.logger.error("Error check refreshing token \(error)")
        }

    }
    
    private func updateUsage() {
        Task { await usageManager.updateUsage() }
    }
    
    private func requestNotificationsPermissions() {
        Task {
            let center = UNUserNotificationCenter.current()


            do {
                try await center.requestAuthorization(options: [.alert, .sound, .badge])
                logger.info("Got notifications permission")
            } catch {
                logger.error(["Failed to get notifications permission:" , error])
                error.reportToSentry()
            }
        }
        
    }
    
    func enumerateAllDomains() {
        Task {
            do {
                let domains = try await NSFileProviderManager.domains()
                
                guard !domains.isEmpty else {
                    logger.info("📍 No domains registered")
                    return
                }
                
                for domain in domains {
                    await processDomain(domain)
                }
            } catch {
                logger.error("❌ Error getting domains: \(error.localizedDescription)")
            }
        }
    }

    func processDomain(_ domain: NSFileProviderDomain) async {

        guard let manager = NSFileProviderManager(for: domain) else {
            logger.error("⚠️ ⚠️ Could not get manager for domain: \(domain.identifier.rawValue)")
            return
        }

        do {

            try await manager.signalEnumerator(for: .workingSet)
        } catch {
            logger.error("❌ Error enumerating changes for \(domain.identifier.rawValue): \(error.localizedDescription)")
        }
    }

}

