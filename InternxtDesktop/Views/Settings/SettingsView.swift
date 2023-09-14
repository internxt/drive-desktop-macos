//
//  SettingsView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI

enum TabView {
    case General
    case Account
}
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var usageManager: UsageManager
    @State var focusedTab: TabView = .General
    var body: some View {
        
        VStack(alignment: .leading, spacing: 0) {
            VStack(spacing: 0) {
                HStack(spacing: 4) {
                    TabItem(iconName: .Gear, label: "TabGeneral", id: .General)
                    TabItem(iconName: .At, label: "TabAccount", id: .Account)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(colorScheme == .dark ? Color("Gray5") :  Color("Surface"))
                Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color("Gray10")).zIndex(5)
            }
            
            Tabcontent.background(Color("Gray1"))
        }.frame(width: 440, alignment: .topLeading)
        
    }
    
    @ViewBuilder
    var Tabcontent: some View {
        switch self.focusedTab {
        case .General:
            GeneralTabView()
        case .Account:
            AccountTabView()
                .environmentObject(authManager)
                .environmentObject(usageManager)
            
        default:
            EmptyView()
        }
    }
    
    func TabItem(iconName: AppIconName, label: String, id: TabView) -> some View {
        return VStack(alignment: .center, spacing:2) {
            AppIcon(iconName: iconName, color: Color("Gray100"))
            AppText(label).font(.XSMedium)
        }
        
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(colorScheme == .dark ? "Gray10" : "Gray5").opacity(focusedTab == id ? 1 : 0))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
                focusedTab = id
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().frame(width: 400).fixedSize(horizontal: false, vertical: true).environmentObject(AuthManager()).environmentObject(UsageManager())
    }
}
