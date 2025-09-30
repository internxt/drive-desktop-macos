//
//  Windows.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import SwiftUI
import Sparkle


/// Return the default windows config, this
/// windows will be available without needing to explicitly
/// creating them
func defaultWindows(settingsManager: SettingsTabManager, authManager: AuthManager, usageManager: UsageManager, backupsService: BackupsService, scheduleManager: ScheduledBackupManager,antivirusManager : AntivirusManager ,
                    cleanerService: CleanerService,updater: SPUUpdater, closeSendFeedbackWindow: @escaping () -> Void, finishOrSkipOnboarding: @escaping () -> Void) -> [WindowConfig] {
    let windows = [
        WindowConfig(
            view: AnyView(AppSettingsManagerView{SignInWithBrowserView().environmentObject(authManager)}),
            title: nil,
            id: "auth",
            width: 480,
            height: 320,
            fixedToFront: false
        ),
        WindowConfig(
            view:  AnyView(AppSettingsManagerView{ SettingsView(updater: updater)
                    .environmentObject(authManager)
                    .environmentObject(usageManager)
                    .environmentObject(backupsService)
                    .environmentObject(settingsManager)
                    .environmentObject(scheduleManager)
                    .environmentObject(antivirusManager)
                    .environmentObject(cleanerService)
            }),
            title: "Internxt",
            id: "settings",
            width: 400,
            height: 290,
            backgroundColor: Color.Gray5
        ),
        WindowConfig(
            view: AnyView(AppSettingsManagerView { OnboardingView(finishOrSkipOnboarding: finishOrSkipOnboarding) }),
            id: "onboarding",
            width: 800,
            height: 470
        ),
        WindowConfig(
            view: AnyView(AppSettingsManagerView { SendFeedbackView(closeWindow: closeSendFeedbackWindow ) }),
            title: "Internxt Desktop Feedback",
            id: "send-feedback",
            width: 380,
            height: 320
        )
    ]
    
    
    return windows
}
