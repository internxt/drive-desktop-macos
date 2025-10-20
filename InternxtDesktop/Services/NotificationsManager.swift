//
//  NotificationsManager.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/10/25.
//

import Foundation
import UserNotifications
import AppKit

class NotificationsManager: NSObject, ObservableObject {
    
    static let shared = NotificationsManager()
    
    private override init() {
        super.init()
        setupNotificationDelegate()
        setupNotificationCategories()
    }
    
    
    private func setupNotificationDelegate() {
        UNUserNotificationCenter.current().delegate = self
    }
    
    private func setupNotificationCategories() {
        let openAction = UNNotificationAction(
            identifier: "OPEN_ACTION",
            title: "Open",
            options: .foreground
        )
        
        let dismissAction = UNNotificationAction(
            identifier: "DISMISS_ACTION",
            title: "Dismiss",
            options: .destructive
        )
        
        let category = UNNotificationCategory(
            identifier: "GENERAL_NOTIFICATION",
            actions: [openAction, dismissAction],
            intentIdentifiers: [],
            options: []
        )
        
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }
    
    
    func getNotifications() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        
        if settings.authorizationStatus == .notDetermined {
            await requestPermission()
        }
        
        do {
            let notifications = try await APIFactory.GatewayAPI.getNotifications(debug: true)
            
            
            for (_, notification) in notifications.enumerated() {
                sendNotificationWithActions(
                    title: "New Notification",
                    body: notification.message,
                    urlString: notification.link,
                    delay: 1
                )
            }
            
        } catch {
            appLogger.error("❌ Error get notifications: \(error)")
        }
    }
    
    
    private func requestPermission() async {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                appLogger.info("✅ Permissions allowed")
            } else {
                appLogger.info("⚠️ Permissions not allowed")
            }
        } catch {
            appLogger.info("❌ Error getting permissions: \(error.localizedDescription)")
        }
    }
    

    private func sendNotificationWithActions(
        title: String,
        subtitle: String = "",
        body: String,
        urlString: String? = nil,
        delay: TimeInterval = 1,
        userInfo: [String: Any] = [:]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        content.sound = .default
        content.badge = 1
        content.categoryIdentifier = "GENERAL_NOTIFICATION"
        
        var finalUserInfo = userInfo
        if let urlString = urlString {
            finalUserInfo["url"] = urlString
        }
        content.userInfo = finalUserInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                appLogger.info("❌ Error sending notification: \(error.localizedDescription)")
            } else {
                appLogger.info("✅ Notication sended: \(title)")
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationsManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        appLogger.info("🔑 Action Identifier: \(response.actionIdentifier)")
        appLogger.info("📦 UserInfo: \(userInfo)")
        
        switch response.actionIdentifier {
        case "OPEN_ACTION", UNNotificationDefaultActionIdentifier:
            
            if let urlString = userInfo["url"] as? String {
                appLogger.info("🔗 URL: \(urlString)")
                if let url = URL(string: urlString) {
                    let success = NSWorkspace.shared.open(url)
                    appLogger.info(success ? "✅ URL open successfully" : "❌ error to open url")
                } else {
                    appLogger.info("❌ URL wrong: \(urlString)")
                }
            }
            
            NSApp.activate(ignoringOtherApps: true)
            
        case "DISMISS_ACTION":
            appLogger.info("❌ Notification dismissed")
            
        default:
            break
        }
        
        completionHandler()
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }
}
