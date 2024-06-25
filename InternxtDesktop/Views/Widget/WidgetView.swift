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
    @EnvironmentObject var settingsManager: SettingsTabManager
    @EnvironmentObject var backupsService: BackupsService
    @EnvironmentObject var domainManager: FileProviderDomainManager

    @State private var showBackupBanner = false
    var isEmpty: Bool = true
    var openFileProviderRoot: () -> Void
    var openSendFeedback: () -> Void
    let configLoader = ConfigLoader()
    init(openFileProviderRoot:  @escaping () -> Void,openSendFeedback:  @escaping () -> Void) {
        self.openFileProviderRoot = openFileProviderRoot
        self.openSendFeedback = openSendFeedback
    }
    
    
    func shouldDisplayBackupBanner() -> Bool {
        return !self.shouldDisplayActivityEntries() && self.showBackupBanner
    }
    
    func shouldDisplayActivityEntries() -> Bool {
        if backupsService.backupDownloadStatus == .InProgress {
            return true
        }
        
        if !activityManager.activityEntries.isEmpty {
            return true
        }
        
        return false
    }
    
    private func openFileProvider() {
        if domainManager.domainStatus == .FailedToInitialize {
            guard let user = authManager.user else {
                    return
            }
            Task {
                try? await self.domainManager.initFileProviderForUser(user: user)
            }
            return
        }
        
        if domainManager.domainStatus == .Ready {
            return self.openFileProviderRoot()
        }
    }
    var body: some View {
        AppSettingsManagerView {
            VStack(alignment: .leading, spacing: 0) {
                if authManager.user != nil {
                    
                    WidgetHeaderView(
                        user: authManager.user!,
                        openFileProviderRoot: self.openFileProvider,
                        openSendFeedback: self.openSendFeedback
                    )
                        .zIndex(100)
                        .environmentObject(self.globalUIManager)
                        .environmentObject(self.usageManager)
                        .environmentObject(self.settingsManager)

                    if shouldDisplayBackupBanner() {
                        WidgetBackupBannerView() {
                            self.showBackupBanner = false
                        }
                        .environmentObject(self.settingsManager)
                    }

                    VStack(alignment: .center) {
                        if !shouldDisplayActivityEntries() {
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
                            WidgetContentView(activityEntries: $activityManager.activityEntries).environmentObject(backupsService)
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
            .environmentObject(SettingsTabManager())
            .environmentObject(UsageManager())
            .environmentObject(ActivityManager())
            .environmentObject(BackupsService())
    }
}
