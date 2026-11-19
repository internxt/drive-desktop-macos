//
//  MailBridgeErrorView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 17/09/2026.
//

import SwiftUI

struct MailBridgeErrorView: View {
    @ObservedObject var service: MailBridgeService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                MailBridgeGlyph(systemName: "exclamationmark.triangle", tint: .TextRed)

                VStack(alignment: .leading, spacing: 6) {
                    AppText("MAIL_BRIDGE_ERROR_TITLE")
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    AppText("MAIL_BRIDGE_ERROR_DESCRIPTION")
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            MailBridgeCard {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        AppText("MAIL_BRIDGE_ERROR_CARD_TITLE")
                            .font(.SMSemibold)
                            .foregroundColor(.Gray100)

                        Text(service.lastError ?? NSLocalizedString("MAIL_BRIDGE_ERROR_UNKNOWN", comment: "No detail available"))
                            .font(.MailBridgeMono)
                            .foregroundColor(.Gray50)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)

                    if service.isActivatingMailBridge {
                        ProgressView().controlSize(.small)
                    } else {
                        AppButton(
                            title: "MAIL_BRIDGE_ERROR_RETRY",
                            onClick: { Task { await service.retryAfterFailure() } },
                            size: .SM
                        )
                    }
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            }
            .padding(.top, 20)

            HStack(spacing: 14) {
                Button(action: { LogService.shared.getLogsDirectory()?.open() }) {
                    AppText("MAIL_BRIDGE_ERROR_VIEW_LOGS")
                        .font(.XSSemibold)
                        .foregroundColor(.Primary)
                }
                .buttonStyle(.plain)

                Button(action: { URLDictionary.HELP_CENTER.open() }) {
                    AppText("MAIL_BRIDGE_ERROR_CONTACT_SUPPORT")
                        .font(.XSSemibold)
                        .foregroundColor(.Primary)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(action: { service.dismissFailure() }) {
                    AppText("MAIL_BRIDGE_ERROR_DISMISS")
                        .font(.XSSemibold)
                        .foregroundColor(.Gray50)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
