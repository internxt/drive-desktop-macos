//
//  StopBackupDialog.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

struct StopBackupDialog: View {

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_STOP_ONGOING_BACKUP")
                .font(.LGMedium)

            AppText("BACKUP_STOP_BACKUP_BODY")
                .font(.BaseRegular)
                .foregroundColor(.Gray60)

            HStack(spacing: 8) {
                AppButton(title: "COMMON_CANCEL", onClick: {

                }, type: .secondary)

                AppButton(title: "BACKUP_STOP_BACKUP", onClick: {

                }, type: .primary)
            }
            .padding([.top], 8)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
        .cornerRadius(10)
        .frame(width: 320)
    }
}

#Preview {
    StopBackupDialog()
}