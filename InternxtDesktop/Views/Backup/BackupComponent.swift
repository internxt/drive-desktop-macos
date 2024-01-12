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
    var numOfFolders: Int
    var isLoading: Bool
    var lastUpdated: String?
    var backupStorageValue: Int?
    var backupStorageUnit: String?
    @Binding var progress: Double
    @State private var currentFrequency: UploadFrequencyEnum = .six

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            DeviceCardComponent(
                deviceName: self.deviceName,
                isLoading: self.isLoading,
                lastUpdated: self.lastUpdated,
                progress: self.$progress,
                backupStorageValue: self.backupStorageValue,
                backupStorageUnit: self.backupStorageUnit
            )

            HStack(spacing: 8) {
                AppButton(title: "BACKUP_STOP_BACKUP", onClick: {
                    do {
                        try stopBackup()
                    } catch {
                        print("error \(error.reportToSentry())")
                    }
                }, type: .primary)

                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    do {
                        try browseFiles()
                    } catch {
                        print("error \(error.reportToSentry())")
                    }
                }, type: .secondary)
            }
            .frame(maxWidth: .infinity)

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

            VStack(alignment: .leading, spacing: 8) {
                AppText("BACKUP_UPLOAD_DELETE_BACKUP")
                    .font(.SMMedium)
                    .foregroundColor(.Gray80)

                AppText("BACKUP_UPLOAD_DELETE_BACKUP_CONTENT")
                    .font(.SMRegular)
                    .foregroundColor(.Gray50)

                AppButton(title: "BACKUP_UPLOAD_DELETE_BACKUP", onClick: {
                    do {
                        try deleteBackup()
                    } catch {
                        print("error \(error.reportToSentry())")
                    }
                }, type: .secondary)
            }
            .padding([.top], 12)
        }
    }

    func deleteBackup() throws {
        throw AppError.notImplementedError
    }

    func changeFolders() throws {
        throw AppError.notImplementedError
    }

    func stopBackup() throws {
        throw AppError.notImplementedError
    }

    func browseFiles() throws {
        throw AppError.notImplementedError
    }

}

#Preview {
    BackupComponent(deviceName: "Mac Mini M1", numOfFolders: 16, isLoading: false, lastUpdated: "today at 13:34", backupStorageValue: 10, backupStorageUnit: "GB", progress: .constant(0.5))
}
