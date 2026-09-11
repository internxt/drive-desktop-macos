//
//  MailBridgeTabView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 08/09/2026.
//

import SwiftUI

struct MailBridgeTabView: View {
    @ObservedObject var service: MailBridgeService
    @ObservedObject private var featuresService = FeaturesService.shared
    let onOpenSettings: () -> Void

    var body: some View {
        Group {
            if featuresService.isLoading {
                loadingView
            } else {
                switch service.viewState {
                case .locked:
                    MailBridgeLockedView(service: service)
                case .inactive:
                    MailBridgeInactiveView(service: service)
                case .active:
                    MailBridgeActiveView(service: service, onOpenSettings: onOpenSettings)
                }
            }
        }
        .frame(width: 630, height: 430)
        .background(Color.Gray1)
        .animation(.easeInOut, value: service.viewState)
        .onAppear {
            determineViewState()
        }
        .onChange(of: featuresService.mailEnabled) { _ in
            determineViewState()
        }
    }

    private func determineViewState() {
        if !featuresService.mailEnabled {
            service.viewState = .locked
        } else if service.viewState == .locked {
            service.viewState = .inactive
        }
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            AppText("MAIL_BRIDGE_CHECKING_AVAILABILITY")
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
