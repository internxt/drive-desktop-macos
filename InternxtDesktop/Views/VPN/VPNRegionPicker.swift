//
//  VPNRegionPicker.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import InternxtSwiftCore
import SwiftUI

struct VPNRegionPicker: View {
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    @ObservedObject var service: VPNService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppText("VPN_REGION_PICKER_TITLE")
                .font(.SMSemibold)
                .foregroundColor(.Gray100)

            LazyVGrid(columns: Self.columns, alignment: .leading, spacing: 8) {
                ForEach(service.regions) { region in
                    VPNRegionChip(
                        region: region,
                        isSelected: service.selectedRegion == region.location,
                        onSelect: { service.select(region) }
                    )
                }
            }
        }
    }
}

private struct VPNRegionChip: View {
    let region: VPNRegion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(region.location.flag)
                    .font(.system(size: 16))
                    .opacity(region.isAvailable ? 1 : 0.5)

                AppText(region.location.nameKey)
                    .font(.XSSemibold)
                    .foregroundColor(region.isAvailable ? .Gray100 : .Gray50)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer(minLength: 0)

                if !region.isAvailable {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.Gray50)
                } else if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.Primary)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.PrimaryBadge : Color.Gray5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.Primary : Color.Gray10, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Free plan") {
    VPNRegionPicker(service: VPNService())
        .padding(20)
        .frame(width: 630)
}

#Preview("All regions") {
    VPNRegionPicker(service: VPNService(
        regions: VPNZone.allCases.map { VPNRegion(location: $0, isAvailable: true) },
        selectedRegion: .germany,
        isFreePlan: false
    ))
    .padding(20)
    .frame(width: 630)
}
