//
//  SettingsMenuView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import SwiftUI

struct SettingsMenuView: View {
    var body: some View {
        GeometryReader { proxy in
            
            ZStack {
                VStack(alignment: .leading, spacing: 0) {
                    SettingsMenuOption(label: "PreferencesOption")
                    SettingsMenuOption(label: "SendFeedbackOption")
                    SettingsMenuOption(label: "SupportOption")
                    SettingsMenuOption(label: "LogoutOption")
                    Rectangle()
                    .foregroundColor(.clear)
                    .frame(width: 140, height: 1)
                    .background(Color("Gray10"))
                    SettingsMenuOption(label: "QuitOption")
                    
                   
                }
                .padding(.vertical, 6).overlay {
                    RoundedRectangle(cornerRadius: 8).stroke(Color("Gray20"), lineWidth: 1)
                }
                .background(Color("Gray1"))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.1), radius: 12.5, x: 0, y: 20)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 8)
                
            }.offset(x: -(140 - 32), y: proxy.size.height + 4).zIndex(10)
            
        }.frame(width: 140)
    }
    
    func SettingsMenuOption(label: String) -> some View {
        return HStack(alignment: .center, spacing: 0) {
            AppText(label)
                .font(AppTextFont["SM/Regular"])
                .padding(.horizontal, 12)
                .frame(height: 32)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    
}

struct SettingsMenu_Previews: PreviewProvider {
    static var previews: some View {
        SettingsMenuView()
        
    }
}
