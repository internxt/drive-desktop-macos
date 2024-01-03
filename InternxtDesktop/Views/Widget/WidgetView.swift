//
//  WidgetView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import FileProvider
import RealmSwift

struct WidgetView: View {
    @EnvironmentObject var activityManager: ActivityManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var globalUIManager: GlobalUIManager
    @EnvironmentObject var usageManager: UsageManager

    @State private var showBackupBanner = false
    var isEmpty: Bool = true
    var openFileProviderRoot: () -> Void
    var openSendFeedback: () -> Void
    let configLoader = ConfigLoader()
    init(openFileProviderRoot:  @escaping () -> Void,openSendFeedback:  @escaping () -> Void) {
        self.openFileProviderRoot = openFileProviderRoot
        self.openSendFeedback = openSendFeedback
    }
    var body: some View {
        AppSettingsManagerView {
            VStack(alignment: .leading, spacing: 0) {
                if authManager.user != nil {
                    
                    WidgetHeaderView(user: authManager.user!, openFileProviderRoot: openFileProviderRoot, openSendFeedback: self.openSendFeedback)
                        .zIndex(100)
                        .environmentObject(self.globalUIManager)
                        .environmentObject(self.usageManager)

                    if !activityManager.activityEntries.isEmpty && self.showBackupBanner {
                        WidgetBackupBannerView() {
                            self.showBackupBanner = false
                        }
                    }

                    VStack(alignment: .center) {
                        
                        if activityManager.activityEntries.isEmpty {
                            Image("SyncedStack")
                               .resizable()
                               .scaledToFit()
                               .frame(maxWidth: 128)
                            VStack {
                                AppText("FILES_UP_TO_DATE")
                                    .font(.BaseMedium)
                                    .foregroundColor(.Gray100)
                                AppText("FILES_UP_TO_DATE_HINT")
                                    .font(.SMRegular)
                                    .foregroundColor(.Gray60)
                            }
                            .padding(.top, 22)
                        } else {
                            WidgetContentView(activityEntries: $activityManager.activityEntries)
                        }
                    }.frame(maxWidth: .infinity,maxHeight: .infinity)
                    WidgetFooterView()
                } else {
                    Spacer()
                    AppText("Loading user...").foregroundColor(.Highlight)
                    Spacer()
                }
                
            }
            .frame(width: 330, height: 400)
            .background(Color.Surface)
            .cornerRadius(10)
        }
        .onAppear {
            self.showBackupBanner = configLoader.shouldShowBackupsBanner()
        }

    }
}

struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetView(openFileProviderRoot: {}, openSendFeedback: {})
            .environmentObject(AuthManager())
            .environmentObject(GlobalUIManager())
            .environmentObject(UsageManager())
            .environmentObject(ActivityManager())
    }
}
