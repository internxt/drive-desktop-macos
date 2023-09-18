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
                .frame(maxWidth: .infinity, maxHeight: 1).overlay(Color.Gray10)
            HStack(alignment: .center, spacing: 0) {
                DisplayStatus()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
        }.background(colorScheme == .dark ? Color.Gray1 :  Color.Gray1)
    }
    
    func DisplayStatus() -> some View {
        return HStack(alignment: .center, spacing: 8){
            ZStack {
                Circle().foregroundColor(.Primary).frame(height: 20 )
                AppIcon(iconName: .Check, size: 12, color: Color.white)
                
            }.padding(2)
            AppText("SYNC_STATUS_UP_TO_DATE").font(.SMMedium)
            
        }
    }
    
   
}

struct WidgetFooterView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetFooterView().frame(maxWidth: 300)
    }
}
