//
//  WidgetDeviceSelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI
import InternxtSwiftCore

struct WidgetDeviceSelector: View {

    @StateObject var backupsService: BackupsService
    @Binding var selectedDevice: Device?
    @Binding var selectedDeviceId: Int?

    var body: some View {
        Group {
            switch backupsService.deviceResponse {
            case .success(let devices):
                if devices.isEmpty {
                    VStack(alignment: .center) {
                        Spacer()

                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(2.0, anchor: .center)

                        Spacer()
                    }
                    .frame(width: 160, alignment: .center)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(devices) { device in
                            DeviceItem(
                                deviceName: device.plainName ?? "",
                                isSelected: self.selectedDeviceId == device.id,
                                isCurrentDevice: device.isCurrentDevice
                            ) {
                                withAnimation {
                                    self.selectedDeviceId = device.id
                                    self.selectedDevice = device
                                }
                            }
                        }
                    }
                    .onAppear {
                        self.selectedDeviceId = devices.first?.id
                        self.selectedDevice = devices.first
                    }
                    .frame(width: 160, alignment: .leading)
                }
            case .failure(_):
                VStack(alignment: .center, spacing: 20) {
                    Spacer()

                    AppText("BACKUP_ERROR_FETCHING_DEVICES")
                        .font(.SMMedium)
                        .multilineTextAlignment(.center)

                    AppButton(title: "BACKUP_TRY_AGAIN") {
                        Task {
                            await backupsService.loadAllDevices()
                        }
                    }

                    Spacer()
                }
                .frame(width: 160, alignment: .center)
            default:
                VStack(alignment: .center) {
                    Spacer()

                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                        .scaleEffect(2.0, anchor: .center)

                    Spacer()
                }
                .frame(width: 160, alignment: .center)
            }
        }
        .onAppear {
            Task {
                await backupsService.loadAllDevices()
            }
        }
    }
}

struct DeviceItem: View {
    
    @Environment(\.colorScheme) var colorScheme
    var deviceName: String
    var isSelected: Bool
    var isCurrentDevice: Bool
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
    WidgetDeviceSelector(backupsService: BackupsService(), selectedDevice: .constant(nil), selectedDeviceId: .constant(nil))
}
