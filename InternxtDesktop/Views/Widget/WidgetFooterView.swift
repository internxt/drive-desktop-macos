//
//  WidgetFooterView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct WidgetFooterView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10"))
            HStack(alignment: .center, spacing: 16) {
                DisplayStatus()
                Spacer()
                AppText(getVersion())
                    .foregroundColor(Color("Highlight"))
            }.padding(.horizontal, 10)
                .padding(.vertical, 0)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
        }.background(colorScheme == .dark ? Color("Gray1") :  Color("Gray1"))
    }
    
    func DisplayStatus() -> some View {
        return HStack(alignment: .center, spacing: 8){
            ZStack {
                Circle().foregroundColor(Color("Primary")).frame(height: 20 )
                AppIcon(iconName: .Check, size: 12, color: Color("Highlight"))
                
            }
            AppText("SyncStatusUpToDate").font(AppTextFont["SM/Medium"])
            
        }
    }
    
    func getVersion() -> String {
        guard let version = Bundle.main.releaseVersionNumber else {
            return "NO_VERSION"
        }
        guard let buildNumber = Bundle.main.buildVersionNumber else {
            return "NO_BUILD_NUMBER"
        }
        
        return "\(version) (\(buildNumber))"
    }
}

struct WidgetFooterView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetFooterView().frame(maxWidth: 300)
    }
}
