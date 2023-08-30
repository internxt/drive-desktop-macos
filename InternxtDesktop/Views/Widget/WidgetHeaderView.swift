//
//  WidgetHeaderView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import InternxtSwiftCore
struct WidgetHeaderView: View {
    private let user: DriveUser
    init(user: DriveUser?) {
        self.user = user!
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                AppText(user.email).font(AppTextFont["SM/Medium"]).foregroundColor(Color("Highlight"))
            }.padding(.horizontal, 10)
                .padding(.vertical, 0)
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
            
            Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10"))

        }.background(Color("Gray1"))
    }
}

struct WidgetHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetHeaderView(user: nil)
    }
}
