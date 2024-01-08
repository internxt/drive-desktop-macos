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
        VStack(alignment: .leading) {
            ForEach(devices) { item in
                DeviceItem(deviceName: item.name, isCurrentDevice: item.isCurrentDevice, isSelected: self.selectedIndex == item.index) {
                    withAnimation {
                        self.selectedIndex = item.index
                    }
                }
            }
        }
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
        .background(Color.clear)
        .padding([.horizontal], 16)
        .padding([.vertical], 10)
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
}

#Preview {
    WidgetDeviceSelector()
}
