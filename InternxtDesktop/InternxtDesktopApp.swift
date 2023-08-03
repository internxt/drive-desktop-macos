//
//  App.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import SwiftUI

@main
struct InternxtDesktopApp: App {
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
