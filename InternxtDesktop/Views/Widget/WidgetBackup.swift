//
//  WidgetBackup.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

enum UploadFrequencyEnum: String {
    case six = "6", twelve = "12", daily = "24", manually = "0"
}

struct WidgetBackup: View {

    @Environment(\.colorScheme) var colorScheme
    var deviceName: String
    var numOfFolders: Int
    var isLoading: Bool
    var lastUpdated: String?
    var backupStorageValue: Int?
    var backupStorageUnit: String?
    @Binding var progress: Double
    @State private var progressBarWidth: CGFloat = .zero
    @State private var currentFrequency: UploadFrequencyEnum = .six

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            DeviceCard

            ButtonsToRender

            FolderSelection
                .padding([.top], 12)

            UploadFrequency
                .padding([.top], 12)

            DeleteBackup
                .padding([.top], 12)
        }
    }

    var DeviceCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(.gray)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 0) {
                    AppText(deviceName)
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)

                    if isLoading {
                        ProgressField
                    } else {
                        Text("BACKUP_LAST_UPLOADED_\(lastUpdated ?? "")")
                            .font(.SMRegular)
                            .foregroundColor(.Gray50)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    AppText("\(Int(progress * 100))%")
                        .font(.LGMedium)
                        .foregroundColor(.Primary)
                } else {
                    HStack(spacing: 0) {
                        AppText("\(backupStorageValue ?? 0)")
                            .font(.SMMedium)
                            .foregroundColor(.Gray60)

                        AppText(backupStorageUnit ?? "")
                            .font(.XSMedium)
                            .foregroundColor(.Gray60)
                    }
                    .padding([.vertical], 4)
                    .padding([.horizontal], 8)
                    .background(Color.Gray5)
                    .cornerRadius(8)
                }
            }

            if isLoading {
                // show progress bar
                ProgressBar
            }

        }
        .padding(16)
        .background(colorScheme == .dark ? Color.Gray5 : Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .inset(by: -0.5)
                .stroke(Color.Gray10, lineWidth: 1)
        )
    }

    var ProgressField: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(.Primary)

            AppText("BACKUP_BACKING_UP")
                .font(.SMMedium)
                .foregroundColor(.Primary)
        }
    }

    var ProgressBar: some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.Gray5)
                    .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 4)
                    .onAppear {
                        progressBarWidth = proxy.size.width
                    }
            }

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.Primary)
                .frame(width: progressBarWidth * progress, height: 4)
        }
        .frame(height: 5, alignment: .leading)
    }

    var ButtonsToRender: some View {
        HStack(spacing: 8) {
            AppButton(title: "BACKUP_STOP_BACKUP", onClick: {

            }, type: .primary)

            AppButton(title: "BACKUP_BROWSE_FILES", onClick: {

            }, type: .secondary)
        }
        .frame(maxWidth: .infinity)
    }

    var FolderSelection: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_SELECTED_FOLDERS")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            HStack(spacing: 10) {
                AppButton(title: "BACKUP_CHANGE_FOLDERS", onClick: {

                }, type: .secondary)

                Text("BACKUP_\("\(numOfFolders)")_NUMBER_OF_FOLDERS_SELECTED")
                    .font(.SMRegular)
                    .foregroundColor(.Gray60)
            }
        }
    }

    var UploadFrequency: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_UPLOAD_FREQUENCY")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            AppSelector(
                size: .MD,
                options: [
                    AppSelectorOption(value: UploadFrequencyEnum.six.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_6_HRS"),
                    AppSelectorOption(value: UploadFrequencyEnum.twelve.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_12_HRS"),
                    AppSelectorOption(value: UploadFrequencyEnum.daily.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_EVERY_DAY"),
                    AppSelectorOption(value: UploadFrequencyEnum.manually.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_MANUALLY"),
                ],
                initialValue: "6",
                position: .top
            ) { selectedOption in
                switch selectedOption.value {
                case "6":
                    self.currentFrequency = .six
                case "12":
                    self.currentFrequency = .twelve
                case "24":
                    self.currentFrequency = .daily
                default:
                    self.currentFrequency = .manually
                }
            }

            if self.currentFrequency == .manually {
                AppText("BACKUP_UPLOAD_FREQUENCY_MANUALLY_TOOLTIP")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: true, vertical: true)
            }
        }
    }

    var DeleteBackup: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_UPLOAD_DELETE_BACKUP")
                .font(.SMMedium)
                .foregroundColor(.Gray80)

            AppText("BACKUP_UPLOAD_DELETE_BACKUP_CONTENT")
                .font(.SMRegular)
                .foregroundColor(.Gray50)

            AppButton(title: "BACKUP_UPLOAD_DELETE_BACKUP", onClick: {

            }, type: .secondary)
        }
    }
}

#Preview {
    WidgetBackup(deviceName: "Mac Mini M1", numOfFolders: 16, isLoading: false, lastUpdated: "today at 13:34", backupStorageValue: 10, backupStorageUnit: "GB", progress: .constant(0.5))
}
