//
//  GeneralTabView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI

struct GeneralTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .center, spacing: 0) {
                AppText("DeviceName")
                    .font(.SMMedium)
                    .background(Color.clear)
                DeviceNameView()
            }.frame(maxWidth: .infinity)
            Divider()
                .background(Color("Gray10")).padding(.vertical, 24)
            VStack(alignment: .leading,spacing: 0) {
                StartOnLaunchView()
                HStack(spacing:24) {
                    
                }.padding(.top, 20)
            }
            Divider().background(Color("Gray10")).padding(.vertical, 24)
            HStack {
                VStack(alignment: .leading) {
                    AppText("Internxt Drive v\(getVersion())")
                        .font(.SMMedium)
                        .foregroundColor(Color("Gray100"))
                    AppText("Last checked: Feature not ready")
                        .font(.XSRegular)
                        .foregroundColor(Color("Gray60"))
                }
                Spacer()
                AppButton(title: "CheckForUpdates", onClick: handleCheckUpdates, type: .secondaryWhite, size: .MD)
                
            }.padding(.bottom, 16)
            AppText("LearnMoreAboutInternxtDrive")
                .contentShape(Rectangle())
                .onTapGesture{
                    handleOpenLearnMore()
                }
                .font(.BaseRegular)
                .foregroundColor(Color("Primary"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        
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
        if let url = URL(string: URLDictionary.LEARN_MORE_ABOUT_INTERNXT_DRIVE) {
               NSWorkspace.shared.open(url)
        }
    }
    func handleCheckUpdates() {}
}

struct GeneralTabView_Previews: PreviewProvider {
    static var previews: some View {
        GeneralTabView().frame(width: 440)
    }
}
