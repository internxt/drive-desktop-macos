//
//  BackupsTabView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct BackupsTabView: View {

    @Binding var showFolderSelector: Bool
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @StateObject var backupsService: BackupsService
    private let deviceName = ConfigLoader().getDeviceName()
    @State var hasBackup = false
    @State var selectedDeviceId = 0
    @State var progress: Double = 0.48

    var body: some View {
        HStack(spacing: 0) {
            DevicesTab
                .padding([.leading, .vertical], 20)
                .padding([.trailing], 16)

            Divider()
                .background(Color.Gray10)
                .padding([.vertical], 20)

            BackupTab

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var DevicesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_SETTINGS_DEVICES")
                .foregroundColor(.Gray80)
                .font(.SMMedium)

            WidgetDeviceSelector(backupsService: backupsService)

            Spacer()

            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .frame(width: 12, height: 12)
                AppText("BACKUP_SETTINGS_DEVICES_HELP")
                    .foregroundColor(.Gray60)
                    .font(.XSRegular)
            }
            .onTapGesture {
                URLDictionary.HELP_CENTER.open()
            }
        }
    }

    var BackupTab: some View {
        Group {
            if selectedDeviceId == 0 {
                if hasBackup {
                    ScrollView(showsIndicators: false) {
                        BackupComponent(
                            deviceName: deviceName ?? "",
                            isCurrentDevice: true,
                            numOfFolders: 20,
                            isLoading: true,
                            progress: $progress,
                            showStopBackupDialog: $showStopBackupDialog,
                            showDeleteBackupDialog: $showDeleteBackupDialog
                        )
                    }
                } else {
                    VStack {
                        Spacer()

                        BackupSetupComponent {
                            showFolderSelector = true
                        }

                        Spacer()
                    }
                    .padding(20)
                }
            } else {
                BackupComponent(
                    deviceName: "Home PC",
                    isCurrentDevice: false,
                    numOfFolders: 0,
                    isLoading: false,
                    lastUpdated: "November 24, 2022 at 13:34",
                    backupStorageValue: 65,
                    backupStorageUnit: "GB",
                    progress: .constant(1),
                    showStopBackupDialog: $showStopBackupDialog,
                    showDeleteBackupDialog: $showDeleteBackupDialog
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

}

#Preview {
    BackupsTabView(showFolderSelector: .constant(false), showStopBackupDialog: .constant(false), showDeleteBackupDialog: .constant(false), backupsService: BackupsService())
}
