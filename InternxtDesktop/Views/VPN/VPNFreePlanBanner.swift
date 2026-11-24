//
//  VPNFreePlanBanner.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

struct VPNFreePlanBanner: View {
    var body: some View {
        AppCard(fill: .PrimaryBadge, stroke: Color.Primary.opacity(0.3)) {
            HStack(spacing: 12) {
                Image(systemName: "speedometer")
                    .font(.system(size: 16))
                    .foregroundColor(.Primary)

                VStack(alignment: .leading, spacing: 2) {
                    AppText("VPN_FREE_PLAN_TITLE")
                        .font(.XSSemibold)
                        .foregroundColor(.Gray100)
                    AppText("VPN_FREE_PLAN_DESCRIPTION")
                        .font(.XSRegular)
                        .foregroundColor(.Gray60)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                AppButton(
                    title: "VPN_UPGRADE",
                    onClick: { URLDictionary.UPGRADE_PLAN.open() },
                    size: .SM
                )
            }
            .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        }
    }
}

#Preview {
    VPNFreePlanBanner()
        .padding(20)
        .frame(width: 630)
}
