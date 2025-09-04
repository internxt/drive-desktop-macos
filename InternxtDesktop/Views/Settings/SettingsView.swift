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
    case Antivirus
    case Cleaner
}
struct SettingsView: View {
    @Environment(\.colorScheme) var colorScheme
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var backupsService: BackupsService
    @EnvironmentObject var settingsManager: SettingsTabManager
    @EnvironmentObject var scheduleManager: ScheduledBackupManager
    @EnvironmentObject var antivirusManager: AntivirusManager
    @EnvironmentObject var cleanerService: CleanerService
    public var updater: SPUUpdater? = nil
    @State private var selectedDevice: Device? = nil
    @State private var showFolderSelector = false
    @State private var showStopBackupDialog = false
    @State private var showDeleteBackupDialog = false
    @State private var isEditingSelectedFolders: Bool = false
    @State private var showBackupContentNavigator: Bool = false
    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    HStack(spacing: 4) {
                        TabItem(iconName: .Gear, label: "SETTINGS_TAB_GENERAL_TITLE", id: .General)
                        TabItem(iconName: .At, label: "SETTINGS_TAB_ACCOUNT_TITLE", id: .Account)
                        TabItem(iconName: .ClockCounterClockwise, label: "SETTINGS_TAB_BACKUPS_TITLE", id: .Backup)
                        TabItem(iconName: .Shield, label: "SETTINGS_TAB_ANTIVIRUS_TITLE", id: .Antivirus)
                        TabItem(iconName: .Shield, label: "SETTINGS_TAB_CLEANER_TITLE", id: .Cleaner)
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
                    FolderSelectorView(
                        backupsService: backupsService,
                        closeWindow: {
                            isEditingSelectedFolders = false
                            showFolderSelector = false
                        },
                        isEditingSelectedFolders: $isEditingSelectedFolders
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Gray40.opacity(0.4))
            }
            
            if showBackupContentNavigator {
                if let device = self.selectedDevice,
                    self.showBackupContentNavigator,
                    let bucketId = device.bucket {
                    BackupContentNavigator(
                        device: device,
                        onClose: {
                            self.showBackupContentNavigator = false
                        }, backupsService: backupsService
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.Gray40.opacity(0.4))
                }
            }

            // stop ongoing backup dialog
            if showStopBackupDialog {
                VStack {
                    StopBackupDialogView(backupsService: backupsService, onClose: {
                        showStopBackupDialog = false
                    })
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Gray40.opacity(0.4))
            }

            // delete backup dialog
            if showDeleteBackupDialog {
                VStack {
                    DeleteBackupDialogView(
                        selectedDevice: self.$selectedDevice,
                        backupsService: backupsService,
                        onClose: {
                            withAnimation {
                                showDeleteBackupDialog = false
                            }
                            
                        }
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.Gray40.opacity(0.4))
            }
        }
        .frame(width: 630)
        .onChange(of: scheduleManager.backupError) { error in
            if !error.isEmpty {
                showErrorDialog(message: error)
            }
        }
    }
    
    private func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    @ViewBuilder
    var Tabcontent: some View {
        switch settingsManager.focusedTab {
        case .General:
            GeneralTabView(updater: updater)
        case .Account:
            AccountTabView()
                .environmentObject(authManager)
                .environmentObject(usageManager)
        case .Backup:
            BackupsTabView(selectedDevice: $selectedDevice, showFolderSelector: $showFolderSelector, showStopBackupDialog: $showStopBackupDialog, showDeleteBackupDialog: $showDeleteBackupDialog,
                isEditingSelectedFolders: $isEditingSelectedFolders, showBackupContentNavigator:$showBackupContentNavigator,
                backupsService: backupsService,
                scheduleManager: scheduleManager
            )
        case .Antivirus:
            AntivirusTabView(viewModel: antivirusManager)
        case .Cleaner:
            CleanerTabView(cleanerService: cleanerService)
 
        }
    }
    
    func TabItem(iconName: AppIconName, label: String, id: TabView) -> some View {
        return VStack(alignment: .center, spacing:2) {
            AppIcon(iconName: iconName, size: 28, color: Color("Gray100"))
            AppText(label).font(.XSMedium)
        }
        
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(colorScheme == .dark ? "Gray10" : "Gray5").opacity(settingsManager.focusedTab == id ? 1 : 0))
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            settingsManager.focusedTab = id
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView().frame(width: 600, height: 460).fixedSize(horizontal: false, vertical: true).environmentObject(AuthManager()).environmentObject(UsageManager())
    }
}
