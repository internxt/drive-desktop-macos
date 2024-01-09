//
//  UploadFrequencySelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct UploadFrequencySelector: View {
    @Binding var currentFrequency: UploadFrequencyEnum

    var body: some View {
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
                initialValue: UploadFrequencyEnum.six.rawValue,
                position: .top
            ) { selectedOption in
                switch selectedOption.value {
                case UploadFrequencyEnum.six.rawValue:
                    self.currentFrequency = .six
                case UploadFrequencyEnum.twelve.rawValue:
                    self.currentFrequency = .twelve
                case UploadFrequencyEnum.daily.rawValue:
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
}

#Preview {
    UploadFrequencySelector(currentFrequency: .constant(.six))
}
