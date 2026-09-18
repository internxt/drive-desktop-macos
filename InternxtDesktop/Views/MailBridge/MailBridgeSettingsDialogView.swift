//
//  MailBridgeSettingsDialogView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI

struct MailBridgeSettingsDialogView: View {
    @ObservedObject var service: MailBridgeService
    let onClose: () -> Void

    @State private var autostart: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                AppText("MAIL_BRIDGE_SETTINGS_TITLE")
                    .font(.BaseSemibold)
                    .foregroundColor(.Gray100)
                Text(String(
                    format: NSLocalizedString("MAIL_BRIDGE_SETTINGS_SUBTITLE_%@", comment: "Which account the settings apply to"),
                    service.accountEmail
                ))
                .font(.XSRegular)
                .foregroundColor(.Gray50)
            }
            .padding(EdgeInsets(top: 18, leading: 20, bottom: 14, trailing: 20))

            MailBridgeDivider()

            VStack(alignment: .leading, spacing: 0) {
                AppCheckbox(label: "MAIL_BRIDGE_AUTOSTART_TITLE", checked: $autostart)
                AppText("MAIL_BRIDGE_AUTOSTART_DIALOG_NOTE")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 28)
                    .padding(.top, 3)
            }
            .padding(EdgeInsets(top: 16, leading: 20, bottom: 16, trailing: 20))

            MailBridgeDivider()

            HStack(spacing: 10) {
                Spacer()
                AppButton(title: "COMMON_CANCEL", onClick: onClose, type: .secondary, size: .SM)
                AppButton(title: "MAIL_BRIDGE_SAVE_CHANGES", onClick: save, size: .SM)
            }
            .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        }
        .frame(width: 430)
        .background(Color.DefaultBackground)
        .cornerRadius(MailBridgeMetrics.cardRadius)
        .overlay(
            RoundedRectangle(cornerRadius: MailBridgeMetrics.cardRadius, style: .continuous)
                .stroke(Color.Gray10, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        .onAppear {
            autostart = service.activateAtLaunch
        }
    }

    private func save() {
        service.activateAtLaunch = autostart
        onClose()
    }
}
