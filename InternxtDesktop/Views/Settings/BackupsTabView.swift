//
//  BackupsTabView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct BackupsTabView: View {
    @EnvironmentObject var usageManager: UsageManager

    var body: some View {
        HStack(spacing: 16) {
            DevicesTab

            Divider()
                .background(Color.Gray10)

            BackupTab

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }

    var DevicesTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("Devices")
                .foregroundColor(.Gray80)
                .font(.SMMedium)

            WidgetDeviceSelector()

            Spacer()

            HStack(alignment: .center, spacing: 4) {
                Rectangle()
                    .fill(.gray)
                    .frame(width: 16, height: 16)
                AppText("Backups help")
                    .foregroundColor(.Gray60)
                    .font(.XSRegular)
            }
            .onTapGesture {
                URLDictionary.HELP_CENTER.open()
            }

        }
    }

    var BackupTab: some View {
        VStack(spacing: 16) {
            Image("DriveIcon")
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 0) {
                AppText("INTERNXT BACKUPS")
                    .foregroundColor(.Gray100)
                    .font(.XSSemibold)

                AppText("Save a copy of your most important files on the cloud automatically")
                    .foregroundColor(.Gray60)
                    .font(.BaseRegular)
                    .multilineTextAlignment(.center)
            }

            AppButton(title: "Backup now", onClick: {
                handleOpenBackupFolders()
            }, type: .primary, size: .MD)
        }
        .padding(20)
    }

    func handleOpenBackupFolders() -> Void {
        Task { await usageManager.updateUsage() }
        NSApp.sendAction(#selector(AppDelegate.openFolderSelector), to: nil, from: nil)
    }
}

#Preview {
    BackupsTabView()
}
