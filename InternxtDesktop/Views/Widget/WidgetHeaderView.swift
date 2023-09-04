//
//  WidgetHeaderView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import InternxtSwiftCore
struct WidgetHeaderView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.openWindow) var openWindow
    @State var settingsMenuOpen = false
    private let user: DriveUser?
    private let openFileProviderRoot: () -> Void
    init(user: DriveUser?, openFileProviderRoot: @escaping () -> Void) {
        self.user = user
        self.openFileProviderRoot = openFileProviderRoot
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .center, spacing: 0) {
                Avatar()
                UserInfo().padding(.leading, 10)
                Spacer()
                RightActions()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading).zIndex(10)
            Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10")).zIndex(5)

        }.background(colorScheme == .dark ? Color("Gray5") :  Color("Gray1"))
    }
    
    func Avatar() -> some View {
        let initial = user?.name.first
        return HStack(alignment: .center){
            AppText(String(initial ?? "M"))
                .font(AppTextFont["Base/Semibold"])
                .foregroundColor(colorScheme == .dark ? Color.white : Color("Primary"))
                
        }
        .frame(width: 36, height: 36)
        .background(Color("Primary").opacity(colorScheme == .dark ? 0.75 : 0.2))
        .cornerRadius(999)
    }
    
    func UserInfo() -> some View {
        VStack(alignment: .leading, spacing:0) {
            // Disable email detection
            Text(verbatim: user?.email ?? "No user found")
                .font(AppTextFont["SM/Medium"])
                .foregroundColor(Color("Gray100"))
                .lineLimit(1)
            AppText("Using 0.4GB of 200GB")
                .font(AppTextFont["XS/Medium"])
                .foregroundColor(Color("Gray50"))
                .lineLimit(1)
            
        }
        
    }
    
    func RightActions() -> some View{
        HStack(alignment: .center, spacing: 0) {
            WidgetIconButtonView(iconName: .Globe, onClick: self.openDriveWeb)
                .padding(.leading, 1)
            WidgetIconButtonView(iconName: .FolderSimple, onClick: self.openFileProviderRoot)
                .padding(.leading, 1)
            WidgetIconButtonView(iconName: .Gear, onClick: self.openSettings).overlay(alignment: .bottomLeading) {
                SettingsMenuView().opacity(settingsMenuOpen ? 1 : 0)
                
            }
        
        }
    }
    
    func openDriveWeb() {
        if let url = URL(string: URLDictionary.DRIVE_WEB) {
               NSWorkspace.shared.open(url)
        }
    }
    
    func openSettings() {
        withAnimation(.linear(duration: 0.1)){
            settingsMenuOpen = !settingsMenuOpen
        }
       
    }
    
    
}

struct WidgetHeaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            WidgetHeaderView(user: nil, openFileProviderRoot: {})
        }.frame(width: 300, height: 300)
    }
        
}
