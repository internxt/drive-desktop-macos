//
//  ContentView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.openWindow) var openWindow
    init() {
    }
    var body: some View {
        Button("Sign out", action: {
            openWindow(id: "AuthWindow")
        })
        WidgetView()
       
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
