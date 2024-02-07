//
//  BackupComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

enum UploadFrequencyEnum: String {
    case six = "6", twelve = "12", daily = "24", manually = "0"
}

struct BackupComponent: View {

    var deviceName: String
    var isCurrentDevice: Bool
    var numOfFolders: Int
    var isLoading: Bool
    var lastUpdated: String?
    @Binding var progress: Double
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @State private var currentFrequency: UploadFrequencyEnum = .six

    private var formattedDate: String {
        guard let lastUpdated, let lastUpdatedDate = Time.dateFromISOString(lastUpdated) else {
            return ""
        }
        return Time.stringDateFromDate(lastUpdatedDate, dateStyle: .long, timeStyle: .short)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            DeviceCardComponent(
                deviceName: self.deviceName,
                isLoading: self.isLoading,
                lastUpdated: formattedDate,
                progress: self.$progress
            )

            HStack(spacing: 8) {
                if isCurrentDevice {
                    AppButton(title: "BACKUP_STOP_BACKUP", onClick: {
                        showStopBackupDialog = true
                    }, type: .primary, isExpanded: true)
                } else {
                    AppButton(title: "BACKUP_DOWNLOAD", onClick: {
                        do {
                            try downloadBackup()
                        } catch {
                            print("error \(error.reportToSentry())")
                        }
                    }, type: .primary, isExpanded: true)
                }

                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    browseFiles()
                }, type: .secondary, isExpanded: true)
            }
            .frame(maxWidth: .infinity)

            if isCurrentDevice {
                VStack(alignment: .leading, spacing: 8) {
                    AppText("BACKUP_SELECTED_FOLDERS")
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)

                    HStack(spacing: 10) {
                        AppButton(title: "BACKUP_CHANGE_FOLDERS", onClick: {
                            do {
                                try changeFolders()
                            } catch {
                                print("error \(error.reportToSentry())")
                            }
                        }, type: .secondary)

                        Text("BACKUP_\("\(numOfFolders)")_NUMBER_OF_FOLDERS_SELECTED")
                            .font(.SMRegular)
                            .foregroundColor(.Gray60)
                    }
                }
                .padding([.top], 12)

                UploadFrequencySelector(currentFrequency: self.$currentFrequency)
                    .padding([.top], 12)
            }

            VStack(alignment: .leading, spacing: 8) {
                AppText("BACKUP_UPLOAD_DELETE_BACKUP")
                    .font(.SMMedium)
                    .foregroundColor(.Gray80)

                AppText("BACKUP_UPLOAD_DELETE_BACKUP_CONTENT")
                    .font(.SMRegular)
                    .foregroundColor(.Gray50)

                AppButton(title: "BACKUP_UPLOAD_DELETE_BACKUP", onClick: {
                    showDeleteBackupDialog = true
                }, type: .secondary)
            }
            .padding([.top], 12)
        }
        .padding([.vertical, .trailing], 20)
        .padding([.leading], 16)
    }

    func downloadBackup() throws {
        throw AppError.notImplementedError
    }

    func changeFolders() throws {
        throw AppError.notImplementedError
    }

    func browseFiles() {
        URLDictionary.BACKUPS_WEB.open()
    }

}

#Preview {
    BackupComponent(deviceName: "Mac Mini M1", isCurrentDevice: true, numOfFolders: 16, isLoading: false, lastUpdated: "2016-06-05T16:56:57.019+01:00", progress: .constant(0.5), showStopBackupDialog: .constant(false), showDeleteBackupDialog: .constant(false))
}
