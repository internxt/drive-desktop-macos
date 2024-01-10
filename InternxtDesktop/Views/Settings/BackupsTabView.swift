//
//  BackupsTabView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct BackupsTabView: View {

    @Binding var showFolderSelector: Bool

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
            AppText("BACKUP_SETTINGS_DEVICES")
                .foregroundColor(.Gray80)
                .font(.SMMedium)

            WidgetDeviceSelector()

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
        VStack(spacing: 16) {
            Image("DriveIcon")
                .resizable()
                .frame(width: 80, height: 80)

            VStack(spacing: 0) {
                AppText("INTERNXT_BACKUPS")
                    .foregroundColor(.Gray100)
                    .font(.XSSemibold)

                AppText("BACKUP_SETTINGS_TOOLTIP")
                    .foregroundColor(.Gray60)
                    .font(.BaseRegular)
                    .multilineTextAlignment(.center)
            }

            AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                withAnimation {
                    showFolderSelector = true
                }
            }, type: .primary, size: .MD)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
    }

}

#Preview {
    BackupsTabView(showFolderSelector: .constant(false))
}
