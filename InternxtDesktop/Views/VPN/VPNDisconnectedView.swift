//
//  VPNDisconnectedView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

struct VPNDisconnectedView: View {
    @ObservedObject var service: VPNService

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                AppGlyph(icon: .system("network.slash"), size: 56)

                VStack(alignment: .leading, spacing: 6) {
                    AppText("VPN_OFF_TITLE")
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    AppText("VPN_OFF_DESCRIPTION")
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            AppCard {
                VStack(alignment: .leading, spacing: 16) {
                    VPNRegionPicker(service: service)

                    HStack {
                        Spacer(minLength: 0)
                        AppButton(title: "VPN_CONNECT", onClick: { service.connect() })
                    }
                }
                .padding(EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 18))
            }
            .padding(.top, 20)

            if service.isFreePlan {
                VPNFreePlanBanner()
                    .padding(.top, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("Free plan") {
    VPNTabView(service: VPNService())
}

#Preview("Paid plan") {
    VPNTabView(service: VPNService(
        regions: [
            VPNRegion(location: .france, isAvailable: true),
            VPNRegion(location: .germany, isAvailable: true),
            VPNRegion(location: .poland, isAvailable: true),
            VPNRegion(location: .canada, isAvailable: false),
            VPNRegion(location: .unitedKingdom, isAvailable: false)
        ],
        selectedRegion: .poland,
        isFreePlan: false
    ))
}
