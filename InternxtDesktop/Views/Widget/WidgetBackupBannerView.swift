//
//  WidgetBackupBannerView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/19/23.
//

import SwiftUI

struct ImageContainerView: View {
    var body: some View {
        Color.clear
            .overlay (
                Image("backupBanner")
                    .clipped()
                    .position(x: 50, y: 95)
            )
            .clipped()
    }
}

struct WidgetBackupBannerView: View {

    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 0) {

            ImageContainerView()
                .frame(width: 112, height: 134)

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 0) {
                        AppText("INTERNXT_BACKUPS")
                            .font(.XSSemibold)
                            .foregroundColor(.Gray80)
                            .padding([.top], 4)

                        Spacer(minLength: 4)

                        Image(systemName: "xmark")
                            .frame(width: 20, height: 20)
                            .foregroundColor(.Gray60)
                            .onTapGesture {
                                withAnimation {
                                    dismiss()
                                }
                            }

                    }

                    AppText("BACKUPS_BODY")
                        .font(.XSRegular)
                        .foregroundColor(.Gray80)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppButton(title: "BACKUP_BUTTON_LABEL", onClick: {
                    handleOpenPreferences()
                }, size: .SM)
            }
            .padding([.leading], 16)
            .padding([.vertical, .trailing], 8)
        }
        .background(Color.Gray1)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0.0, y: 1.0)
        .padding([.horizontal, .top], 12)

    }

    func handleOpenPreferences() -> Void {
        NSApp.sendAction(#selector(AppDelegate.openSettingsWindow), to: nil, from: nil)
    }
}

#Preview {
    WidgetBackupBannerView() {}
}
