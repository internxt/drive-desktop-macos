//
//  UploadFrequencySelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct BackupFrequencySelectorView: View {
    @Binding var currentFrequency: BackupFrequencyEnum
    @Binding var nextBackupTime: String
    public let onClick: (BackupFrequencyEnum) -> Void
    @Binding var isDisabled: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_UPLOAD_FREQUENCY")
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            HStack(spacing: 12){
                AppSelector(
                    size: .MD,
                    options: [
                        AppSelectorOption(value: BackupFrequencyEnum.hour.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_1_HRS"),
                        AppSelectorOption(value: BackupFrequencyEnum.six.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_6_HRS"),
                        AppSelectorOption(value: BackupFrequencyEnum.daily.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_EVERY_DAY"),
                        AppSelectorOption(value: BackupFrequencyEnum.manually.rawValue, label: "BACKUP_UPLOAD_FREQUENCY_MANUALLY"),
                    ],
                    initialValue: currentFrequency.rawValue,
                    position: .top
                
                    ,onSelectOption:  { selectedOption in
                        setFrequency(option: selectedOption)
                        self.onClick(self.currentFrequency)
                        
                    }, isDisabled : isDisabled)
                    .frame(width: 150)
               
                if self.currentFrequency != .manually {
                    AppText(String(format: NSLocalizedString("BACKUP_NEXT_DATE", comment: ""), nextBackupTime))
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                   
                }

            }


            if self.currentFrequency == .manually {
                AppText("BACKUP_UPLOAD_FREQUENCY_MANUALLY_TOOLTIP")
                    .frame(width: 375,alignment: .leading)
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                 
            }
        }
    }
    
    private func setFrequency(option:AppSelectorOption){
        switch option.value {
        case BackupFrequencyEnum.six.rawValue:
            self.currentFrequency = .six
        case BackupFrequencyEnum.hour.rawValue:
            self.currentFrequency = .hour
        case BackupFrequencyEnum.daily.rawValue:
            self.currentFrequency = .daily
        default:
            self.currentFrequency = .manually
        }
    }
}

#Preview {
    BackupFrequencySelectorView(currentFrequency: .constant(.six), nextBackupTime: .constant(""), onClick: {_ in }, isDisabled: .constant(true))
}
