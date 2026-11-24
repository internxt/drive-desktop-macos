//
//  VPNConnectingView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import InternxtSwiftCore
import SwiftUI

struct VPNConnectingView: View {
    enum Phase {
        case connecting(VPNZone)
        case reconnecting(VPNZone)
        case disconnecting
    }

    let phase: Phase
    var onDisconnect: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .scaleEffect(1.2)

            Text(title)
                .font(.BaseMedium)
                .foregroundColor(.Gray100)

            if let subtitleKey {
                AppText(subtitleKey)
                    .font(.SMRegular)
                    .foregroundColor(.Gray60)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420)
            }

            if let onDisconnect {
                AppButton(title: "VPN_DISCONNECT", onClick: onDisconnect, type: .secondary, size: .SM)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        switch phase {
        case .connecting(let location):
            return String(format: NSLocalizedString("VPN_CONNECTING_TO_%@", comment: "Connecting to a region"), regionName(location))
        case .reconnecting(let location):
            return String(format: NSLocalizedString("VPN_RECONNECTING_TO_%@", comment: "Reconnecting to a region"), regionName(location))
        case .disconnecting:
            return NSLocalizedString("VPN_DISCONNECTING", comment: "Disconnecting from the VPN")
        }
    }

    private var subtitleKey: String? {
        switch phase {
        case .reconnecting: return "VPN_RECONNECTING_DESCRIPTION"
        case .connecting, .disconnecting: return nil
        }
    }

    private func regionName(_ location: VPNZone) -> String {
        NSLocalizedString(location.nameKey, comment: "Region name")
    }
}

#Preview("Connecting") {
    VPNTabView(service: VPNService(viewState: .connecting(.france)))
}

#Preview("Reconnecting") {
    VPNTabView(service: VPNService(viewState: .reconnecting(.germany)))
}

#Preview("Disconnecting") {
    VPNTabView(service: VPNService(viewState: .disconnecting))
}
