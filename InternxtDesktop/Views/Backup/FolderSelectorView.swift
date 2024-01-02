//
//  FolderSelectorView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct FolderSelectorView: View {

    @State private var numberOfFolders = 0
    @State private var isBackupButtonEnabled = false

    var body: some View {
        VStack(spacing: 12) {

            HStack {
                AppText("BACKUP_SETTINGS_BACKUP_FOLDERS")
                    .font(.LGMedium)
                    .foregroundColor(.Gray100)

                Spacer()

                AppText("BACKUP_SETTINGS_FOLDERS")
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
            }

            VStack {
                AppText("BACKUP_SETTINGS_ADD_FOLDERS")
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(8.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(Color.Gray10, lineWidth: 1)
            )

            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: {

                    }, type: .secondary, size: .SM)

                    AppButton(icon: .Minus, title: "", onClick: {

                    }, type: .secondary, size: .SM)
                }

                Spacer()

                HStack {
                    AppButton(title: "COMMON_CANCEL", onClick: {

                    }, type: .secondary, size: .SM)

                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {

                    }, type: .primary, size: .SM, isEnabled: $isBackupButtonEnabled)
                }
            }

        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
    }
}

#Preview {
    FolderSelectorView()
}
