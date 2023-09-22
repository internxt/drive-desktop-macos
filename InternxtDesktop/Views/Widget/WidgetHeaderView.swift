//
//  WidgetHeaderView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import InternxtSwiftCore
import Combine

struct WidgetHeaderView: View {
    @EnvironmentObject var globalUIManager: GlobalUIManager
    @EnvironmentObject var usageManager: UsageManager
    @Environment(\.colorScheme) var colorScheme

    @State var settingsMenuOpen = false
    private let user: DriveUser?
    private let openFileProviderRoot: () -> Void
    private let openSendFeedback: () -> Void
    private var listenWidgetClose: AnyCancellable?
    init(user: DriveUser?, openFileProviderRoot: @escaping () -> Void, openSendFeedback: @escaping () -> Void) {
        self.user = user
        self.openFileProviderRoot = openFileProviderRoot
        self.openSendFeedback = openSendFeedback
    }
    
  
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .center, spacing: 0) {
                AppAvatar(name: user?.name, avatarURL: user?.avatar)
                UserInfo().padding(.leading, 10)
                Spacer()
                RightActions()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
            .zIndex(10)
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .overlay(Color.Gray10)
                .zIndex(5)

        }
        .background(colorScheme == .dark ? Color.Gray5 :  Color.Gray1)
        .onChange(of: globalUIManager.widgetIsOpen, perform: {widgetIsOpen in
            if (widgetIsOpen == false) {
                settingsMenuOpen = false
            }
        })
    }
    
    
    
    func UserInfo() -> some View {
        VStack(alignment: .leading, spacing:0) {
            // Disable email detection
            Text(verbatim: user?.email ?? "No user found")
                .font(.SMMedium)
                .foregroundColor(.Gray100)
                .lineLimit(1)
                .help(user?.email ?? "No user found")
            Text("COMMON_USAGE_\(usageManager.getFormattedTotalUsage())_OF_\(usageManager.format(bytes: usageManager.limit))").font(.XSMedium)
                .foregroundColor(.Gray50)
        }
        
    }
    
    func RightActions() -> some View {
        return HStack(alignment: .center, spacing: 0) {
            WidgetIconButtonView(iconName: .Globe, onClick: self.openDriveWeb)
                
            WidgetIconButtonView(iconName: .FolderSimple, onClick: self.openFileProviderRoot)
                .padding(.horizontal, 1)
            WidgetIconButtonView(iconName: .Gear, onClick: self.openSettings).ifAvailable{view in
                
                if #available(macOS 12, *) {
                    view.overlay(alignment: .bottomLeading) {
                        SettingsMenuView(openSendFeedback: self.openSendFeedback).opacity((settingsMenuOpen) ? 1 : 0).environmentObject(usageManager)
                    }
                } else {
                    view.overlay(SettingsMenuView(openSendFeedback: self.openSendFeedback).opacity((settingsMenuOpen) ? 1 : 0).environmentObject(usageManager)
                                 ,alignment: .bottomLeading)
                }
                    
            }
        
        }
    }
    
    func openDriveWeb() {
        URLDictionary.DRIVE_WEB.open()
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
            WidgetHeaderView(user: nil, openFileProviderRoot: {}, openSendFeedback: {})
                .environmentObject(GlobalUIManager())
                .environmentObject(UsageManager())
        }.frame(width: 300, height: 300)
    }
        
}
