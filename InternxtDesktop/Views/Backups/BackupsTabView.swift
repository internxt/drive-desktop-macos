//
//  BackupsTabView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct BackupsTabView: View {
    
    @Binding var selectedDeviceId: Int?
    @Binding var showFolderSelector: Bool
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @Binding var isEditingSelectedFolders: Bool
    @StateObject var backupsService: BackupsService
    private let deviceName = ConfigLoader().getDeviceName()
    
    
    func getSelectedDevice() -> Device? {
        return backupsService.selectedDevice
    }
    
    func hasSelectedDevice() -> Bool {
        guard getSelectedDevice() != nil else {
            return false
        }
        
        return true
    }
    
    func deviceHasBackups() -> Bool {
        return true
    }
    
    func backupIsInProgress() -> Bool {
        return backupsService.backupStatus == .InProgress
    }
    
    func thereAreDevicesLoaded() -> Bool {
        do {
            let devices = try backupsService.deviceResponse?.get()
            return devices?.isEmpty ?? false ? false : true
        } catch {
            return false
        }
    }
    
    func shouldDisplayBackupsSidebar() -> Bool {
        return backupsService.selectedDevice != nil || backupsService.devicesFetchingStatus == .Ready
    }
    var body: some View {
        Group {
            if(backupsService.devicesFetchingStatus == .LoadingDevices && backupsService.selectedDevice == nil) {
             HStack(alignment: .center, spacing: 8) {
             Spacer()
             ProgressView()
             .progressViewStyle(CircularProgressViewStyle(tint: .blue))
             .scaleEffect(0.6, anchor: .center)
             AppText("BACKUP_FETCHING_DEVICES")
             .font(.SMMedium)
             .multilineTextAlignment(.center)
             
             Spacer()
             }.frame(maxWidth: .infinity, maxHeight: .infinity)
             }
            
            if(backupsService.devicesFetchingStatus == .Failed) {
                VStack(alignment: .center, spacing: 20) {
                    Spacer()
                    AppText("BACKUP_ERROR_FETCHING_DEVICES")
                        .font(.SMMedium)
                        .multilineTextAlignment(.center)
                    
                    AppButton(title: "BACKUP_TRY_AGAIN") {
                        Task {
                            await backupsService.addCurrentDevice()
                            await backupsService.loadAllDevices()
                        }
                    }
                    Spacer()
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if(shouldDisplayBackupsSidebar()){
                HStack(spacing: 0) {
                    BackupsSidebar
                        .padding([.leading, .vertical], 20)
                        .padding([.trailing], 16)
                        .frame(alignment: .topLeading)
                    
                    Divider()
                        .background(Color.Gray10)
                        .padding([.vertical], 20)
                    
                    BackupTab
                    
                }.frame(maxWidth: .infinity, minHeight: 360, maxHeight: .infinity)
            }
            
            
        }.onAppear{
            Task {
                await backupsService.addCurrentDevice()
                await backupsService.loadAllDevices()
            }
        }
    }
    
    var BackupsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            BackupAvailableDevicesView(
                backupsService: backupsService,
                selectedDeviceId: $selectedDeviceId
            ).frame(width: 160)
            
            Spacer()
            
            HStack(alignment: .center, spacing: 4) {
                Image(systemName: "questionmark.circle")
                    .resizable()
                    .frame(width: 12, height: 12)
                AppText("BACKUP_SETTINGS_DEVICES_HELP")
                    .foregroundColor(.Gray60)
                    .font(.XSRegular)
            }
            .onTapGesture {
                URLDictionary.HELP_CENTER.open()
            }
        }
    }
    
    var BackupTab: some View {
        Group {
            
            
          
            if(backupIsInProgress() || hasSelectedDevice()) {
                ScrollView(showsIndicators: false) {
                    BackupConfigView(
                        numOfFolders: backupsService.foldersToBackup.count,
                        backupsService: self.backupsService,
                        backupStatus: $backupsService.backupStatus,
                        showStopBackupDialog: $showStopBackupDialog,
                        showDeleteBackupDialog: $showDeleteBackupDialog,
                        showFolderSelector: $showFolderSelector,
                        isEditingSelectedFolders: $isEditingSelectedFolders,
                        device: Binding($backupsService.selectedDevice)!
                    )
                }
            }
            // No device, display nothing
            if(!hasSelectedDevice()) {
                Spacer()
            }
            
            if(!self.deviceHasBackups()) {
                BackupsFeatureNeedsSetupView {
                    isEditingSelectedFolders = false
                    showFolderSelector = true
                }
            }
            
            
        }
    }
}

#Preview {
    BackupsTabView(
        selectedDeviceId: .constant(nil),
        showFolderSelector: .constant(false),
        showStopBackupDialog: .constant(false),
        showDeleteBackupDialog: .constant(false),
        isEditingSelectedFolders: .constant(false),
        backupsService: BackupsService()
    )
}
