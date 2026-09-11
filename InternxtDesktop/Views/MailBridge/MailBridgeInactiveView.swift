//
//  MailBridgeInactiveView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI

struct MailBridgeInactiveView: View {
    @ObservedObject var service: MailBridgeService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                MailBridgeGlyph(systemName: "arrow.left.arrow.right")

                VStack(alignment: .leading, spacing: 6) {
                    AppText("MAIL_BRIDGE_OFF_TITLE")
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    Text(String(
                        format: NSLocalizedString("MAIL_BRIDGE_OFF_DESCRIPTION_%@", comment: "Explains what activating the bridge does"),
                        service.accountEmail
                    ))
                    .font(.SMRegular)
                    .foregroundColor(.Gray60)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }

            MailBridgeActivationCard(service: service, isEnabled: true)
                .padding(.top, 20)

            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.system(size: 13))
                    .foregroundColor(.Primary)
                AppText("MAIL_BRIDGE_LOCALHOST_NOTE")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct MailBridgeActivationCard: View {
    @ObservedObject var service: MailBridgeService
    let isEnabled: Bool

    var body: some View {
        MailBridgeCard {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        AppText("MAIL_BRIDGE_ACTIVATE_TITLE")
                            .font(.SMSemibold)
                            .foregroundColor(.Gray100)
                        AppText("MAIL_BRIDGE_ACTIVATE_SUBTITLE")
                            .font(.XSRegular)
                            .foregroundColor(.Gray50)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)

                    AppButton(
                        title: "MAIL_BRIDGE_ACTIVATE",
                        onClick: { service.activate() },
                        size: .MD,
                        isEnabled: isEnabled
                    )
                }

                MailBridgeDivider().padding(.vertical, 15)

                VStack(alignment: .leading, spacing: 3) {
                    AppCheckbox(
                        label: "MAIL_BRIDGE_AUTOSTART_TITLE",
                        checked: $service.activateAtLaunch
                    )
                    .disabled(!isEnabled)

                    AppText("MAIL_BRIDGE_AUTOSTART_NOTE")
                        .font(.XSRegular)
                        .foregroundColor(.Gray50)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 28)
                }
            }
            .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
        }
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
    }
}
