//
//  BackupsTabView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct BackupsTabView: View {
    
    @Binding var selectedDevice: Device?
    @Binding var showFolderSelector: Bool
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @Binding var isEditingSelectedFolders: Bool
    @Binding var showBackupContentNavigator: Bool
    @StateObject var backupsService: BackupsService
    @StateObject var scheduleManager: ScheduledBackupManager
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
        return backupsService.backupUploadStatus == .InProgress
    }
    
    func thereAreDevicesLoaded() -> Bool {
        do {
            let devices = try backupsService.deviceResponse?.get()
            return devices?.isEmpty ?? false ? false : true
        } catch {
            return false
        }
    }
    
    func selectedDeviceHasBackups() -> Bool {
        guard let device = backupsService.selectedDevice else {
            return false
        }
        return device.hasBackups
    }
    
    func shouldDisableOptions() -> Bool {
        guard let device = backupsService.selectedDevice else {
            return false
        }
        return backupsService.currentBackupState == .locked && device.hasBackups
    }
    
    func shouldDisplayBackupsSidebar() -> Bool {
        return backupsService.selectedDevice != nil || backupsService.devicesFetchingStatus == .Ready
    }
    var body: some View {
        if !selectedDeviceHasBackups() && backupsService.currentBackupState == .locked {
            lockedBackupView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top,20)
        } else {
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
    }

    
    var BackupsSidebar: some View {
        VStack(alignment: .leading, spacing: 8) {
            
            
            BackupAvailableDevicesView(
                backupsService: backupsService,
                selectedDevice: $selectedDevice
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
                        backupUploadStatus: $backupsService.backupUploadStatus,
                        backupDownloadStatus: $backupsService.backupDownloadStatus,
                        showStopBackupDialog: $showStopBackupDialog,
                        showDeleteBackupDialog: $showDeleteBackupDialog,
                        showFolderSelector: $showFolderSelector,
                        isEditingSelectedFolders: $isEditingSelectedFolders,
                        device: Binding($backupsService.selectedDevice)!,
                        showBackupContentNavigator: $showBackupContentNavigator,
                        backupManager: self.scheduleManager
                        
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
    
    
    var lockedBackupView: some View {
        VStack(spacing: 15) {
            AppText("FEATURE_LOCKED")
                .font(.BaseMedium)
                .foregroundColor(.Gray100)
            
            
            AppText("GENERAL_UPGRADE_PLAN")
                .font(.SMRegular)
                .foregroundColor(.Gray80)
            
            AppButton(title: "COMMON_UPGRADE", onClick: {
                URLDictionary.UPGRADE_PLAN.open()
            })
            
            Spacer()
        }
        
    }
}

#Preview {
    BackupsTabView(
        selectedDevice: .constant(BackupsDeviceService.shared.getDeviceForPreview()),
        showFolderSelector: .constant(false),
        showStopBackupDialog: .constant(false),
        showDeleteBackupDialog: .constant(false),
        isEditingSelectedFolders: .constant(false),
        showBackupContentNavigator: .constant(false),
        backupsService: BackupsService(), scheduleManager: ScheduledBackupManager(backupsService: BackupsService())
    )
}
