//
//  DeviceCardComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct BackupStatusView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var backupStatus: BackupStatus
    @Binding var device: Device
    @Binding var progress: Double

    private var formattedDate: String {
        guard let lastUpdatedDate = Time.dateFromISOString(self.device.updatedAt) else {
            return ""
        }
        return Time.stringDateFromDate(lastUpdatedDate, dateStyle: .long, timeStyle: .short)
    }
    
    private func deviceIsRunningBackup() -> Bool {
        
        
        return self.device.isCurrentDevice && self.backupStatus == .InProgress
    }
    
    private func getBackupProgressPercentage() -> String {
        var progress = Float(progress * 100)
        
        if(progress > 100.0) {
            progress = 100.0
        }
        return "\(String(format: "%.2f", progress))%"
    }
    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if self.device.isCurrentDevice {
                    Image("AppleSVG")
                        .resizable()
                        .frame(width: 32, height: 32)
                } else {
                    Image("backup_folder")
                        .resizable()
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 0) {
                    AppText(self.device.plainName ?? "Unknown device")
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)

                    if deviceIsRunningBackup() {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.up.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.Primary)

                            AppText("BACKUP_BACKING_UP")
                                .font(.SMMedium)
                                .foregroundColor(.Primary)
                        }
                    } else {
                        Text("BACKUP_LAST_UPLOADED_\(formattedDate )")
                            .font(.SMRegular)
                            .foregroundColor(.Gray50)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if deviceIsRunningBackup() {
                    AppText(getBackupProgressPercentage())
                        .font(.LGMedium)
                        .foregroundColor(.Primary)
                 
                }
            }

            if deviceIsRunningBackup() {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.Primary))
            }

        }
        .padding(16)
        .background(colorScheme == .dark ? Color.Gray5 : Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.Gray10, lineWidth: 1)
        )
    }
}

#Preview {
    BackupStatusView(
        backupStatus: .constant(.InProgress),
        device: .constant(
            Device(
                id: 1,
                uuid: UUID().uuidString,
                parentId: "parentId",
                parentUuid: UUID().uuidString,
                name: "cqwefweqfwq",
                bucket: nil,
                encryptVersion: nil,
                deleted: false,
                deletedAt: nil,
                removed: false,
                removedAt: nil,
                createdAt: "",
                updatedAt: "",
                userId: 123,
                hasBackups: true
            )
        ),
        progress: .constant(34)
    )
}
