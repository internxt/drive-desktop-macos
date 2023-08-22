//
//  WidgetView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct WidgetView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.openWindow) private var openWindow
    var onLogout: () -> Void
    var openFileProviderRoot: () -> Void
    init(onLogout: @escaping () -> Void, openFileProviderRoot:  @escaping () -> Void) {
        self.onLogout = onLogout
        self.openFileProviderRoot = openFileProviderRoot
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            
            
            if authManager.user != nil {
                WidgetHeaderView(user: authManager.user!)
                VStack {
                    AppButton(title: "Logout", onClick: {
                        openWindow(id: "Auth")
                        onLogout()
                    }).frame(maxWidth: .infinity)
                    AppButton(title: "Open Virtual Drive", onClick: openFileProviderRoot)
                    AppButton(title: "Quit App", onClick: {
                        NSRunningApplication.current.terminate()
                    })
                }.frame(maxHeight: .infinity)
                WidgetFooterView()
            } else {
                Spacer()
                AppText("Loading user...").foregroundColor(Color("Highlight"))
                Spacer()
            }
            
        }.frame(width: 300, height: 400).background(Color("Surface")).cornerRadius(10)
    }
}

struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetView(onLogout: {}, openFileProviderRoot: {})
    }
}
