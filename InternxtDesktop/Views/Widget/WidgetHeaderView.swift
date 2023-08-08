//
//  WidgetHeaderView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct WidgetHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 16) {
                
            }.padding(.horizontal, 10)
                .padding(.vertical, 0)
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
            
            Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10"))

        }.background(Color("Gray1"))
    }
}

struct WidgetHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetHeaderView()
    }
}
