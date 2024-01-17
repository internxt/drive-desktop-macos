//
//  BackupSetupComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/17/24.
//

import SwiftUI

struct BackupSetupComponent: View {
    var callback: () -> Void

    var body: some View {
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

                }
            }, type: .primary, size: .MD)
        }
    }
}

#Preview {
    BackupSetupComponent {}
}
