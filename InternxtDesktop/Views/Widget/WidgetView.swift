//
//  WidgetView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct WidgetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeaderView()
            WidgetContentView()
            WidgetFooterView()
        }.frame(width: 300, height: 400).background(Color.white).cornerRadius(10)
        
    }
}

struct WidgetView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetView()
    }
}
