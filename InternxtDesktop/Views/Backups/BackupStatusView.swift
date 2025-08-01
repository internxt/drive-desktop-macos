//
//  DeviceCardComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct BackupStatusView: View {
    @Environment(\.colorScheme) var colorScheme
    @Binding var backupUploadStatus: BackupStatus
    @Binding var device: Device
    @Binding var progress: Double
    @Binding var backupDownloadStatus: BackupStatus
    @Binding var progressDownload: Double

    private var formattedDate: String {
        guard let lastUpdatedDate = Time.dateFromISOString(self.device.updatedAt) else {
            return ""
        }
        return Time.stringDateFromDate(lastUpdatedDate, dateStyle: .long, timeStyle: .short)
    }
    
    private func deviceIsRunningBackup() -> Bool {
        
        return self.device.isCurrentDevice && self.backupUploadStatus == .InProgress
    }
    
    private func isDownloading() -> Bool {
        return backupDownloadStatus == .InProgress
    }
    
    private func getBackupProgressPercentage() -> String {
        var progress = Float(progress * 100)
        
        if(progress > 100.0) {
            progress = 100.0
        }
        return "\(Int(progress))%"
    }
    private func getBackupProgressPercentage(upload: Bool) -> String {
        let rawProgress = upload ? progress : progressDownload
        var percentage = Float(rawProgress * 100)
        percentage = min(100, max(0, percentage))
        return "\(Int(percentage))%"
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
                    } else if isDownloading() {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down.circle.fill")
                                .resizable()
                                .frame(width: 16, height: 16)
                                .foregroundColor(.Primary)

                            AppText("BACKUP_BACKING_DOWNLOAD")
                                .font(.SMMedium)
                                .foregroundColor(.Primary)
                        }
                    }
                    
                    else {
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
                 
                } else if isDownloading() {
                    AppText(getBackupProgressPercentage(upload: false))
                        .font(.LGMedium)
                        .foregroundColor(.Primary)
                }
            }

            if deviceIsRunningBackup() {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.Primary))
            }else if isDownloading() {
                ProgressView(value: progressDownload)
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
        backupUploadStatus: .constant(.InProgress),
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
        progress: .constant(34),
        backupDownloadStatus: .constant(.InProgress),
        progressDownload: .constant(34)
    )
}
