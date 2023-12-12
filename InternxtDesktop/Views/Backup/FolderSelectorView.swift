//
//  FolderSelectorView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct FolderSelectorView: View {
    var body: some View {
        VStack(spacing: 12) {

            HStack {
                AppText("Backup folders")
                    .font(.LGMedium)
                    .foregroundColor(.Gray100)

                Spacer()

                AppText("0 folders")
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
            }

            VStack {
                AppText("Click + to select the folders\nyou want to back up")
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
                    AppButton(title: "+", onClick: {

                    }, type: .secondary, size: .SM)

                    AppButton(title: "-", onClick: {

                    }, type: .secondary, size: .SM)
                }

                Spacer()

                HStack {
                    AppButton(title: "Cancel", onClick: {

                    }, type: .secondary, size: .SM)

                    AppButton(title: "Backup now", onClick: {

                    }, type: .primary, size: .SM)
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
