//
//  VPNApprovalView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

struct VPNApprovalView: View {
    @ObservedObject var service: VPNService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                AppGlyph(icon: .system("checkmark.shield"), tint: .Primary, size: 56)

                VStack(alignment: .leading, spacing: 6) {
                    AppText("VPN_APPROVAL_TITLE")
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    AppText("VPN_APPROVAL_DESCRIPTION")
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 12) {
                    step(number: 1, key: "VPN_APPROVAL_STEP_OPEN")
                    step(number: 2, key: "VPN_APPROVAL_STEP_ALLOW")
                    step(number: 3, key: "VPN_APPROVAL_STEP_RETURN")

                    HStack(spacing: 10) {
                        Spacer(minLength: 0)
                        AppButton(title: "COMMON_CANCEL", onClick: { service.disconnect() }, type: .secondary)
                        AppButton(title: "VPN_APPROVAL_OPEN_SETTINGS", onClick: { service.openApprovalSettings() })
                    }
                    .padding(.top, 4)
                }
                .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
            }
            .padding(.top, 20)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func step(number: Int, key: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.XSBold)
                .foregroundColor(.Primary)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.PrimaryBadge))

            AppText(key)
                .font(.SMRegular)
                .foregroundColor(.Gray80)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    VPNTabView(service: VPNService(viewState: .needsApproval))
}
