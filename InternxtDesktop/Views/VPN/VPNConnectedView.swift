//
//  VPNConnectedView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import InternxtSwiftCore
import SwiftUI

struct VPNConnectedView: View {
    private static let elapsedFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = .pad
        return formatter
    }()

    @ObservedObject var service: VPNService
    let location: VPNZone
    let since: Date
    let publicAddress: PublicAddressLookup

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                statusCard

                VPNRegionPicker(service: service)
                    .padding(.top, 20)

                if service.isFreePlan {
                    VPNFreePlanBanner()
                        .padding(.top, 16)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var statusCard: some View {
        AppCard(fill: .PrimaryBadge, stroke: Color.Primary.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.GreenDark)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(Color.GreenDark.opacity(0.18), lineWidth: 3))

                    Text(title)
                        .font(.SMSemibold)
                        .foregroundColor(.Gray100)

                    Text(location.flag)
                        .font(.system(size: 14))

                    Spacer(minLength: 8)

                    AppButton(
                        title: "VPN_DISCONNECT",
                        onClick: { service.disconnect() },
                        type: .secondary,
                        size: .SM
                    )
                }

                AppDivider(color: Color.Primary.opacity(0.3))
                    .padding(.top, 13)

                HStack(alignment: .top, spacing: 0) {
                    detail(labelKey: "VPN_EXIT_IP", value: publicAddressValue(\.ip))
                    detail(labelKey: "VPN_EXIT_LOCATION", value: publicAddressValue(\.location))
                    elapsedDetail
                }
                .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        }
    }

    private var title: String {
        String(
            format: NSLocalizedString("VPN_CONNECTED_TO_%@", comment: "Connected to a region"),
            NSLocalizedString(location.nameKey, comment: "Region name")
        )
    }

    private static let unavailable = NSLocalizedString("VPN_PUBLIC_ADDRESS_UNAVAILABLE", comment: "Public IP or location could not be found")

    private func publicAddressValue(_ field: KeyPath<PublicAddress, String>) -> String? {
        switch publicAddress {
        case .loading:
            return nil
        case .unavailable:
            return Self.unavailable
        case .found(let info):
            let value = info[keyPath: field]
            return value.isEmpty ? Self.unavailable : value
        }
    }

    private var elapsedDetail: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            detail(
                labelKey: "VPN_CONNECTED_TIME",
                value: Self.elapsedFormatter.string(from: since, to: context.date)
            )
        }
    }

    private func detail(labelKey: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            AppText(labelKey)
                .font(.XSMedium)
                .foregroundColor(.Gray50)

            Text(value ?? "—")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.Gray100)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Connected") {
    VPNTabView(service: VPNService(
        viewState: .connected(.germany, since: Date().addingTimeInterval(-754), publicAddress: .found(PublicAddress(ip: "185.201.12.44", location: "Frankfurt, Germany"))),
        regions: VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: true) },
        selectedRegion: .germany,
        isFreePlan: false
    ))
}

#Preview("Connected, free plan, address loading") {
    VPNTabView(service: VPNService(viewState: .connected(.france, since: Date().addingTimeInterval(-42), publicAddress: .loading)))
}

#Preview("Connected, address unavailable") {
    VPNTabView(service: VPNService(viewState: .connected(.france, since: Date().addingTimeInterval(-42), publicAddress: .unavailable)))
}
