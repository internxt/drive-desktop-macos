//
//  App.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 17/8/23.
//

import Foundation
import SwiftUI

@main
struct InternxtDesktopApp: App {
    
    @Environment(\.dismiss) private var dismiss
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    func onLoginSuccess() {
        dismiss()
        appDelegate.loginSuccess()
    }
    var body: some Scene {
        
        Settings{}
        WindowGroup("Internxt Drive",  id: "Auth") {
            ContentView(onLoginSuccess: onLoginSuccess).environmentObject(appDelegate.authManager)
                .handlesExternalEvents(preferring: ["internxt"], allowing: ["internxt"])
                .frame(minWidth: 480, maxWidth: 480, minHeight: 320, maxHeight: 320).toolbar(content: {
                    ToolbarItem(placement: .principal){
                       
                    }
                })
        }
        .windowResizability(.contentSize)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.automatic)
    }
}
