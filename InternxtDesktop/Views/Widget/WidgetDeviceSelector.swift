//
//  WidgetDeviceSelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct Device: Identifiable {
    var id = UUID()
    let name: String
    let index: Int
    let isCurrentDevice: Bool
    let isSelected: Bool
}

struct WidgetDeviceSelector: View {
    private let deviceName = ConfigLoader().getDeviceName()
    @State private var devices: [Device] = []
    @State private var selectedIndex = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(devices) { item in
                DeviceItem(deviceName: item.name, isCurrentDevice: item.isCurrentDevice, isSelected: self.selectedIndex == item.index) {
                    withAnimation {
                        self.selectedIndex = item.index
                    }
                }
            }
        }
        .frame(width: 160, alignment: .leading)
        .onAppear {
            devices = [
                Device(name: deviceName ?? "", index: 0, isCurrentDevice: true, isSelected: true),
                Device(name: "Home PC", index: 1, isCurrentDevice: false, isSelected: false),
                Device(name: "Office server", index: 2, isCurrentDevice: false, isSelected: false)
            ]
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
    WidgetDeviceSelector()
}
