//
//  VPNTabView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

struct VPNTabView: View {
    @ObservedObject var service: VPNService

    var body: some View {
        Group {
            switch service.viewState {
            case .checkingAvailability:
                checkingView
            case .disconnected:
                VPNDisconnectedView(service: service)
            case .connected(let location, let exit):
                VPNConnectedView(service: service, location: location, exit: exit)
            }
        }
        .frame(width: 630, height: 430)
        .background(Color.Gray1)
        .animation(.easeInOut, value: service.viewState)
    }

    private var checkingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            AppText("VPN_CHECKING_AVAILABILITY")
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview("Checking availability") {
    VPNTabView(service: VPNService(viewState: .checkingAvailability))
}
