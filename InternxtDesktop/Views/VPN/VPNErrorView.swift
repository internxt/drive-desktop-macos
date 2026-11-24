//
//  VPNErrorView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

struct VPNErrorView: View {
    @ObservedObject var service: VPNService
    let error: VPNError

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                AppGlyph(icon: .system("exclamationmark.triangle"), tint: .TextRed)

                VStack(alignment: .leading, spacing: 6) {
                    AppText(titleKey)
                        .font(.LGSemibold)
                        .foregroundColor(.Gray100)

                    AppText(descriptionKey)
                        .font(.SMRegular)
                        .foregroundColor(.Gray60)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)

                if error != .extensionNotApproved {
                    AppButton(
                        title: "VPN_ERROR_RETRY",
                        onClick: { service.retry() },
                        type: error == .zoneNotPermitted ? .secondary : .primary
                    )
                }

                switch error {
                case .extensionNotApproved:
                    AppButton(title: "VPN_APPROVAL_OPEN_SETTINGS", onClick: { service.openApprovalSettings() })
                case .zoneNotPermitted:
                    AppButton(title: "VPN_UPGRADE", onClick: { URLDictionary.UPGRADE_PLAN.open() })
                case .sessionExpired, .proxyUnreachable, .unknown:
                    EmptyView()
                }
            }
            .padding(.top, 20)

            HStack(spacing: 14) {
                Button(action: { LogService.shared.getLogsDirectory()?.open() }) {
                    AppText("VPN_ERROR_VIEW_LOGS")
                        .font(.XSSemibold)
                        .foregroundColor(.Primary)
                }
                .buttonStyle(.plain)

                Button(action: { URLDictionary.HELP_CENTER.open() }) {
                    AppText("VPN_ERROR_CONTACT_SUPPORT")
                        .font(.XSSemibold)
                        .foregroundColor(.Primary)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var titleKey: String {
        switch error {
        case .extensionNotApproved: return "VPN_ERROR_NOT_APPROVED_TITLE"
        case .sessionExpired: return "VPN_ERROR_SESSION_EXPIRED_TITLE"
        case .zoneNotPermitted: return "VPN_ERROR_ZONE_NOT_PERMITTED_TITLE"
        case .proxyUnreachable: return "VPN_ERROR_PROXY_UNREACHABLE_TITLE"
        case .unknown: return "VPN_ERROR_UNKNOWN_TITLE"
        }
    }

    private var descriptionKey: String {
        switch error {
        case .extensionNotApproved: return "VPN_ERROR_NOT_APPROVED_DESCRIPTION"
        case .sessionExpired: return "VPN_ERROR_SESSION_EXPIRED_DESCRIPTION"
        case .zoneNotPermitted: return "VPN_ERROR_ZONE_NOT_PERMITTED_DESCRIPTION"
        case .proxyUnreachable: return "VPN_ERROR_PROXY_UNREACHABLE_DESCRIPTION"
        case .unknown: return "VPN_ERROR_UNKNOWN_DESCRIPTION"
        }
    }
}

#Preview("Not approved") {
    VPNTabView(service: VPNService(viewState: .failed(.extensionNotApproved)))
}

#Preview("Session expired") {
    VPNTabView(service: VPNService(viewState: .failed(.sessionExpired)))
}

#Preview("Region not in plan") {
    VPNTabView(service: VPNService(viewState: .failed(.zoneNotPermitted)))
}

#Preview("Server unreachable") {
    VPNTabView(service: VPNService(viewState: .failed(.proxyUnreachable)))
}

#Preview("Unknown") {
    VPNTabView(service: VPNService(viewState: .failed(.unknown)))
}
