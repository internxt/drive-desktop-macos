//
//  WidgetFooterView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct WidgetFooterView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10"))
            VStack(alignment: .center, spacing: 16) {
                AppText(getVersion()).foregroundColor(Color("Highlight"))
            }.padding(.horizontal, 10)
                .padding(.vertical, 0)
                .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
            
            
        }.background(Color("Gray1"))
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
        WidgetFooterView()
    }
}
