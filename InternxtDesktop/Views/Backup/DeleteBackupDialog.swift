//
//  DeleteBackupDialog.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

struct DeleteBackupDialog: View {
    
    @Environment(\.colorScheme) var colorScheme
    @Binding var selectedDeviceId: Int?
    @StateObject var backupsService: BackupsService
    var onClose: () -> Void

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
                    onClose()
                }, type: .secondary, isExpanded: true)

                AppButton(title: "BACKUP_YES_DELETE", onClick: {
                    do {
                        try deleteBackup()
                    } catch {
                        error.reportToSentry()
                    }
                }, type: .danger, isExpanded: true)
            }
            .padding([.top], 8)
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
        .cornerRadius(10)
        .frame(width: 320)
        .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
    }

    func deleteBackup() throws {
        Task {
            let _ = try await self.backupsService.deleteBackup(deviceId: self.selectedDeviceId)
            await backupsService.loadAllDevices()
            self.onClose()
        }
    }
}

#Preview {
    DeleteBackupDialog(selectedDeviceId: .constant(nil), backupsService: BackupsService(), onClose: {})
}
