//
//  GeneralTabView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI
import Sparkle

struct GeneralTabView: View {
    public var updater: SPUUpdater? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: 0) {
                AppText("SETTINGS_DEVICE_NAME")
                    .font(.SMMedium)
                    .background(Color.clear)
                DeviceNameView()
            }.frame(maxWidth: .infinity)
            Divider()
                .background(Color.Gray10).padding(.vertical, 24)
            VStack(alignment: .leading,spacing: 0) {
                StartOnLaunchView()
                HStack(spacing:24) {
                    
                }.padding(.top, 20)
            }
            Divider().background(Color.Gray10).padding(.vertical, 24)
            HStack {
                VStack(alignment: .leading) {
                    AppText("Internxt Drive v\(getVersion())")
                        .font(.SMMedium)
                        .foregroundColor(Color.Gray100)
                    Text("SETTINGS_LAST_UPDATE_CHECK_\(getLastUpdateCheck())")
                        .font(.XSRegular)
                        .foregroundColor(Color.Gray60)
                }
                Spacer()
                if let updater = updater {
                    CheckForUpdatesView(updater: updater)
                }
                
            }.padding(.bottom, 16)
            AppText("SETTINGS_LEARN_MORE")
                .contentShape(Rectangle())
                .onTapGesture{
                    handleOpenLearnMore()
                }
                .font(.BaseRegular)
                .foregroundColor(Color.Primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        
    }
    
    func getLastUpdateCheck() -> String {
        if let lastCheck = updater?.lastUpdateCheckDate {
            return lastCheck.timeAgoDisplay()
        } else {
            return ""
        }
    }
    
    func getVersion() -> String {
        guard let version = Bundle.main.releaseVersionNumber else {
            return "NO_VERSION"
        }
        guard let buildNumber = Bundle.main.buildVersionNumber else {
            return "NO_BUILD_NUMBER"
        }
        
        return "\(version).\(buildNumber)"
    }
    func handleOpenLearnMore() {
        URLDictionary.LEARN_MORE_ABOUT_INTERNXT_DRIVE.open()
    }
    func handleCheckUpdates() {}
}

struct GeneralTabView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralTabView().frame(width: 440)
    }
}
