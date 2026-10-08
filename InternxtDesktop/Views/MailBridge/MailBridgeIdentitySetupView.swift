//
//  MailBridgeIdentitySetupView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 17/09/2026.
//

import SwiftUI

struct MailBridgeIdentitySetupView: View {
    @ObservedObject var service: MailBridgeService

    private let stepKeys = [
        "MAIL_BRIDGE_IDENTITY_STEP_1",
        "MAIL_BRIDGE_IDENTITY_STEP_2",
        "MAIL_BRIDGE_IDENTITY_STEP_3"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                MailBridgeGlyph(systemName: "at")

                VStack(alignment: .leading, spacing: 6) {
                    AppText("MAIL_BRIDGE_IDENTITY_TITLE")
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    AppText("MAIL_BRIDGE_IDENTITY_DESCRIPTION")
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MailBridgeCard {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            AppText("MAIL_BRIDGE_IDENTITY_CARD_TITLE")
                                .font(.SMSemibold)
                                .foregroundColor(.Gray100)

                            Text(String(
                                format: NSLocalizedString("MAIL_BRIDGE_IDENTITY_CARD_SUBTITLE_%@", comment: "Which account the web page opens as"),
                                service.accountEmail
                            ))
                            .font(.XSRegular)
                            .foregroundColor(.Gray50)
                            .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)

                        AppButton(title: "MAIL_BRIDGE_IDENTITY_CREATE_ADDRESS", onClick: {
                            URLDictionary.MAIL_WEB.open()
                        }, size: .SM)
                    }

                    MailBridgeDivider().padding(.vertical, 15)

                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(Array(stepKeys.enumerated()), id: \.offset) { index, key in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1)")
                                    .font(.XXSSemibold)
                                    .foregroundColor(.Primary)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(Color.PrimaryBadge))
                                    .overlay(Circle().strokeBorder(Color.Primary.opacity(0.3), lineWidth: 1))

                                AppText(key)
                                    .font(.XSRegular)
                                    .foregroundColor(.Gray60)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            }
            .padding(.top, 20)

            HStack(spacing: 12) {
                if service.isCheckingMailbox {
                    ProgressView()
                        .controlSize(.small)
                        .frame(height: 32)
                } else {
                    AppButton(
                        title: "MAIL_BRIDGE_IDENTITY_RECHECK",
                        onClick: { Task { await service.recheckUserIdentitySetup() } },
                        type: .secondary,
                        size: .SM
                    )
                }

                AppText(service.isCheckingMailbox
                        ? "MAIL_BRIDGE_IDENTITY_CHECKING"
                        : "MAIL_BRIDGE_IDENTITY_NOT_FOUND")
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
