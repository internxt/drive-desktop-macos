//
//  WidgetDeviceSelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct WidgetDeviceSelector: View {

    @StateObject var backupsService: BackupsService
    @State private var selectedDeviceId = 0
    private let currentDeviceName = ConfigLoader().getDeviceName()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(backupsService.devices) { device in
                DeviceItem(
                    deviceName: device.name ?? "",
                    isCurrentDevice: self.currentDeviceName == device.name,
                    isSelected: self.selectedDeviceId == device.id
                ) {
                    withAnimation {
                        self.selectedDeviceId = device.id
                    }
                }
            }
        }
        .frame(width: 160, alignment: .leading)
        .onAppear {
            self.selectedDeviceId = backupsService.devices.first?.id ?? 0
        }
    }
}

struct DeviceItem: View {
    
    @Environment(\.colorScheme) var colorScheme
    var deviceName: String
    var isCurrentDevice: Bool
    var isSelected: Bool
    var onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if (isCurrentDevice) {
                AppText("BACKUP_SETTINGS_THIS_DEVICE")
                    .foregroundColor(.Primary)
                    .font(.XXSSemibold)
            }

            AppText(deviceName)
                .foregroundColor(.Gray80)
                .font(.SMMedium)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal], 16)
        .padding([.vertical], 10)
        .background(getBackgroundColor())
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .cornerRadius(8.0)
        .shadow(color: isSelected ? .black.opacity(0.05) : .clear, radius: 1, x: 0.0, y: 1.0)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .inset(by: -0.5)
                .stroke(isSelected ? Color.Gray10 : .clear, lineWidth: 1)
        )
    }

    func getBackgroundColor() -> Color {
        if isSelected {
            if colorScheme == .dark {
                return Color.Gray5
            } else {
                return .white
            }
        }
        return .clear
    }
}

#Preview {
    WidgetDeviceSelector(backupsService: BackupsService())
}
