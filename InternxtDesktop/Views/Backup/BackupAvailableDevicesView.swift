//
//  WidgetDeviceSelector.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI
import InternxtSwiftCore

struct BackupAvailableDevicesView: View {
    
    @StateObject var backupsService: BackupsService
    @Binding var selectedDeviceId: Int?
    private let deviceName = ConfigLoader().getDeviceName()
    
    func isFetchingBackupDevices() -> Bool {
        return backupsService.devicesFetchingStatus == .LoadingDevices
    }
    func thereAreBackupDevices() -> Bool {
        switch backupsService.deviceResponse {
        case .success(let devices):
            return devices.isEmpty ? false : true
        case .failure:
            return false
        case .none:
            return false
        }
    }
    
    func getBackupDevices() -> [Device] {
        let devices = (try? backupsService.deviceResponse?.get()) ?? []
        
        print("DEVICE", devices)
        
        return devices
    }
    
    func backupDevicesFetchingFailed() -> Bool {
        return backupsService.devicesFetchingStatus == .Failed
    }
    
    var body: some View {
        Group {
            
            if(thereAreBackupDevices() || isFetchingBackupDevices()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 5) {
                        AppText("BACKUP_SETTINGS_DEVICES")
                            .foregroundColor(.Gray80)
                            .font(.SMMedium)
                            
                        if(isFetchingBackupDevices()) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.5, anchor: .center)
                        }
                    }.frame( maxWidth:.infinity,maxHeight: 20, alignment: .leading )
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(getBackupDevices()) { device in
                            
                            if (device.hasBackups || device.plainName == deviceName) {
                                BackupDeviceItem(
                                    deviceName: device.plainName ?? "",
                                    isSelected: self.selectedDeviceId == device.id,
                                    isCurrentDevice: device.isCurrentDevice
                                ) {
                                    self.selectedDeviceId = device.id
                                    backupsService.selectedDevice = device
                                }
                            }
                        }
                    }
                    .onAppear {
                        let devices = getBackupDevices()
                        if(self.selectedDeviceId == nil) {
                            self.selectedDeviceId = devices.first?.id
                            backupsService.selectedDevice = devices.first
                        }
                    }
                }
                .frame(alignment: .leading)
            }
            
            if(backupDevicesFetchingFailed() && !thereAreBackupDevices()) {
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
                .frame(width: .infinity, alignment: .center)
            }
        }
    }
}

struct BackupDeviceItem: View {
    
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
                .lineLimit(1)
            
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding([.horizontal], 16)
        .padding([.vertical], 10)
        .background(getBackgroundColor())
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .help(Text(deviceName))
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
    BackupAvailableDevicesView(backupsService: BackupsService(), selectedDeviceId: .constant(nil)).frame(width: 160, height: 200).padding(16)
}
