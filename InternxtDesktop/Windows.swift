//
//  Windows.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import SwiftUI



/// Return the default windows config, this
/// windows will be available without needing to explicitly
/// creating them
func defaultWindows(authManager: AuthManager, usageManager: UsageManager, finishOrSkipOnboarding: @escaping () -> Void) -> [WindowConfig] {
    let windows = [
        WindowConfig(
            view: AnyView(SignInWithBrowserView().environmentObject(authManager)),
            title: nil,
            id: "auth",
            width: 480,
            height: 320,
            fixedToFront: false
        ),
        WindowConfig(
            view:  AnyView(SettingsView()
                .environmentObject(authManager)
                .environmentObject(usageManager)),
            title: "Internxt Drive",
            id: "settings",
            width: 400,
            height: 290
        ),
        WindowConfig(
            view: AnyView(OnboardingView(finishOrSkipOnboarding: finishOrSkipOnboarding)),
            id: "onboarding",
            width: 800,
            height: 470
        ),
        WindowConfig(
            view: AnyView(SendFeedbackView()),
            title: "Internxt Desktop Feedback",
            id: "send-feedback",
            width: 380,
            height: 320
        )
    ]
    
    
    return windows
}
