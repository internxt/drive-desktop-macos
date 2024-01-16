//
//  SettingsView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI
import Sparkle

enum TabView {
    case General
    case Account
    case Backup
}
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var backupsService: BackupsService
    @State var focusedTab: TabView = .General
    public var updater: SPUUpdater? = nil
    @State private var showFolderSelector = false

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        TabItem(iconName: .Gear, label: "SETTINGS_TAB_GENERAL_TITLE", id: .General)
                        TabItem(iconName: .At, label: "SETTINGS_TAB_ACCOUNT_TITLE", id: .Account)
                        TabItem(iconName: .ClockCounterClockwise, label: "SETTINGS_TAB_BACKUPS_TITLE", id: .Backup)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(colorScheme == .dark ? Color.Gray5 :  Color.Surface)
                    Divider().frame(maxWidth: .infinity, maxHeight: 1).overlay(Color.Gray10).zIndex(5)
                }

                Tabcontent.background(Color.Gray1)
            }

            // folder selector
            if showFolderSelector {
                VStack {
                    FolderSelectorView(backupsService: backupsService) {
                        showFolderSelector = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Gray1.opacity(0.8))
            }
        }
        .frame(width: 600)
    }
    
    @ViewBuilder
    var Tabcontent: some View {
        switch self.focusedTab {
        case .General:
            GeneralTabView(updater: updater)
        case .Account:
            AccountTabView()
                .environmentObject(authManager)
                .environmentObject(usageManager)
        case .Backup:
            BackupsTabView(showFolderSelector: $showFolderSelector)
        default:
            EmptyView()
        }
    }
    
    func TabItem(iconName: AppIconName, label: String, id: TabView) -> some View {
        return VStack(alignment: .center, spacing:2) {
            AppIcon(iconName: iconName, size: 28, color: Color("Gray100"))
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
        SettingsView().frame(width: 600, height: 460).fixedSize(horizontal: false, vertical: true).environmentObject(AuthManager()).environmentObject(UsageManager())
    }
}
