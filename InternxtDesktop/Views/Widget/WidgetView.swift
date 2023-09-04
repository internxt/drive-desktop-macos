//
//  WidgetView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import FileProvider

struct WidgetView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.openWindow) private var openWindow
    var isEmpty: Bool = true
    var onLogout: () -> Void
    var openFileProviderRoot: () -> Void
    init(onLogout: @escaping () -> Void, openFileProviderRoot:  @escaping () -> Void) {
        self.onLogout = onLogout
        self.openFileProviderRoot = openFileProviderRoot
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            if authManager.user != nil {
                WidgetHeaderView(user: authManager.user!, openFileProviderRoot: openFileProviderRoot).zIndex(100)
                VStack(alignment: .center) {
                    if true {
                        Image("SyncedStack")
                           .resizable()
                           .scaledToFit()
                           .frame(maxWidth: 128)
                        VStack {
                            AppText("FilesUpToDate")
                                .font(AppTextFont["Base/Medium"])
                                .foregroundColor(Color("Gray100"))
                            AppText("FilesUpToDateHint")
                                .font(AppTextFont["SM/Regular"])
                                .foregroundColor(Color("Gray60"))
                        }
                        .padding(.top, 22)
                    } else {
                        WidgetContentView()
                    }
                }.frame(maxWidth: .infinity,maxHeight: .infinity)
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
            .environmentObject(AuthManager())
            .environmentObject(DomainManager(
                domain: NSFileProviderDomain(identifier: NSFileProviderDomainIdentifier("demo"), displayName: "demo"),
                uploadProgress: nil, downloadProgress: nil
            ))
    }
}
