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

    @State private var imapText: String = ""
    @State private var smtpText: String = ""
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

                MailBridgeDivider().padding(.vertical, 16)

                AppText("MAIL_BRIDGE_LOCAL_PORTS")
                    .font(.SMSemibold)
                    .foregroundColor(.Gray100)
                AppText("MAIL_BRIDGE_LOCAL_PORTS_NOTE")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .padding(.top, 3)

                HStack(spacing: 10) {
                    MailBridgePortField(titleKey: "MAIL_BRIDGE_IMAP", text: $imapText)
                    MailBridgePortField(titleKey: "MAIL_BRIDGE_SMTP", text: $smtpText)
                }
                .padding(.top, 11)

                AppText("MAIL_BRIDGE_RESTART_NOTE")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 10)
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
            imapText = String(service.imapPort)
            smtpText = String(service.smtpPort)
            autostart = service.activateAtLaunch
        }
    }

    private func save() {
        service.applyPorts(
            imap: Int(imapText) ?? service.imapPort,
            smtp: Int(smtpText) ?? service.smtpPort
        )
        service.activateAtLaunch = autostart
        onClose()
    }
}
