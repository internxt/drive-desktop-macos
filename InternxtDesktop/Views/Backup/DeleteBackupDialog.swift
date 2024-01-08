//
//  DeleteBackupDialog.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

struct DeleteBackupDialog: View {
    
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_DELETE_BACKUP_TITLE")
                .font(.LGMedium)

            AppText("BACKUP_DELETE_BACKUP_CONTENT")
                .font(.BaseRegular)
                .foregroundColor(.Gray60)

            AppText("BACKUP_DELETE_BACKUP_TOOLTIP")
                .font(.BaseRegular)
                .foregroundColor(.Gray60)

            HStack(spacing: 8) {
                AppButton(title: "COMMON_CANCEL", onClick: {

                }, type: .secondary)

                AppButton(title: "BACKUP_YES_DELETE", onClick: {

                }, type: .danger)
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
    DeleteBackupDialog()
}
