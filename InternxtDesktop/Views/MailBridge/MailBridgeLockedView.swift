//
//  MailBridgeLockedView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI

struct MailBridgeLockedView: View {
    @ObservedObject var service: MailBridgeService

    var body: some View {
        VStack(spacing: 15) {
            MailBridgeGlyph(systemName: "lock", tint: .Orange)
                .padding(.top, 6)

            AppText("MAIL_BRIDGE_LOCKED_TITLE")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)

            AppText("MAIL_BRIDGE_LOCKED_SUBTITLE")
                .font(.SMRegular)
                .foregroundColor(.Gray80)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 420)

            AppButton(title: "MAIL_BRIDGE_UPGRADE_ULTIMATE") {
                URLDictionary.UPGRADE_PLAN.open()
            }

            MailBridgeActivationCard(service: service, isEnabled: false)
                .padding(.top, 5)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
