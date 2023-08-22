//
//  ContentView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    private var onLoginSuccess: () -> Void
    init(onLoginSuccess: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
    }
    
    var body: some View {
        SignInWithBrowserView(onLoginSuccess: onLoginSuccess).environmentObject(authManager)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(onLoginSuccess: {})
    }
}
