//
//  BackupComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/5/24.
//

import SwiftUI

enum UploadFrequencyEnum: String {
    case six = "6", twelve = "12", daily = "24", manually = "0"
}

struct BackupConfigView: View {
    var numOfFolders: Int
    @StateObject var backupsService: BackupsService
    @Binding var backupUploadStatus: BackupStatus
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @Binding var showFolderSelector: Bool
    @Binding var isEditingSelectedFolders: Bool
    @Binding var device: Device
    @Binding var showBackupContentNavigator: Bool
    @State var backupManager: ScheduledBackupManager
    @ObservedObject var appSettings = AppSettings.shared
    @State private var selectedFrequency: BackupFrequencyEnum = AppSettings.shared.selectedBackupFrequency
    @State private var showModalCancel = false
    var body: some View {
        
            
            ZStack {

                VStack(alignment: .leading, spacing: 8) {
                    AppText("BACKUP_TITLE")
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)
                    
                    BackupStatusView(
                        backupUploadStatus: self.$backupUploadStatus,
                        device: self.$device,
                        progress: $backupsService.backupUploadProgress
                    )
                    
                    BackupActionsView.frame(maxWidth: .infinity)
                    
                    if self.device.isCurrentDevice {
                        VStack(alignment: .leading, spacing: 8) {
                            AppText("BACKUP_SELECTED_FOLDERS")
                                .font(.SMMedium)
                                .foregroundColor(.Gray80)
                            HStack(spacing: 10) {
                                if backupsService.thereAreMissingFoldersToBackup {
                                    AppButton(title: "BACKUP_CHANGE_FOLDERS", onClick: {
                                        fixMissingFolders()
                                    }, type: .secondary, size: .MD  , isEnabled: !shouldDisableOptions())
                                    HStack(spacing:4) {
                                        ZStack {
                                            Color.white.ignoresSafeArea().frame(width:12, height:12).clipShape(RoundedRectangle(cornerRadius: 100))
                                            Image("warning-circle-fill")
                                                .renderingMode(.template)
                                                .resizable()
                                                .frame(width:16, height: 16)
                                                .foregroundColor(.Red)
                                        }
                                        
                                        
                                        
                                        Text("BACKUP_MISSING_FOLDERS_ERROR")
                                            .font(.SMRegular)
                                            .foregroundColor(.Red)
                                    }
                                } else {
                                    AppButton(title: "BACKUP_CHANGE_FOLDERS", onClick: {
                                        changeFolders()
                                    }, type: .secondary, size: .MD , isEnabled: !shouldDisableOptions())
                                    
                                    Text("BACKUP_\("\(numOfFolders)")_NUMBER_OF_FOLDERS_SELECTED")
                                        .font(.SMRegular)
                                        .foregroundColor(.Gray60)
                                }
                            }
                            
                        }
                        .padding([.top], 12)
                    }
                   
                    if self.device.isCurrentDevice {
                        BackupFrequencySelectorView(currentFrequency: $appSettings.selectedBackupFrequency, nextBackupTime: $backupManager.nextBackupTime, onClick: { option in
                            // restart date
                            self.removeBackupDate()
                            self.backupManager.startBackupTimer(frequency: option)
                        }, isDisabled: .constant(shouldDisableOptions()))
                        .padding([.vertical, .trailing], 20)
                    }
                    
                    
                    VStack(alignment: .leading, spacing: 8) {
                        AppText("BACKUP_UPLOAD_DELETE_BACKUP")
                            .font(.SMMedium)
                            .foregroundColor(.Gray80)
                        
                        AppText("BACKUP_UPLOAD_DELETE_BACKUP_CONTENT")
                            .font(.SMRegular)
                            .foregroundColor(.Gray50)
                        
                        AppButton(title: "BACKUP_UPLOAD_DELETE_BACKUP", onClick: {
                            showDeleteBackupDialog = true
                        }, type: .secondary, isEnabled: !shouldDisableOptions())
                    }
                    .padding([.top], 12)
                }
                .padding([.vertical, .trailing], 20)
                .padding([.leading], 16)
                
                if showModalCancel {
                    CustomModalView(
                        title: "FEATURE_LOCKED",
                        message: "GENERAL_UPGRADE_PLAN",
                        cancelTitle: "COMMON_CANCEL",
                        confirmTitle: "COMMON_UPGRADE",
                        confirmColor: .blue,
                        onCancel: {
                            self.showModalCancel = false
                        },
                        onConfirm: {
                            
                            URLDictionary.UPGRADE_PLAN.open()
                            self.showModalCancel = false
                        }
                    )
                }
            }
        
    }
    
    func isDownloadingBackup() -> Bool {
        return self.device.id == backupsService.deviceDownloading?.id && backupsService.backupDownloadStatus == .InProgress
    }
    
    func shouldDisableOptions() -> Bool {
        guard let device = backupsService.selectedDevice else {
            return false
        }
        return backupsService.currentBackupState == .locked && device.hasBackups
    }
    
    var BackupActionsView: some View {
        HStack(spacing: 8) {
            if self.device.isCurrentDevice {
                if self.backupUploadStatus == .InProgress {
                    AppButton(title: "BACKUP_STOP_BACKUP", onClick: {
                        showStopBackupDialog = true
                    }, type: .primary, isExpanded: true)
                } else {
                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                        
                        if backupsService.currentBackupState == .active {
                            Task {
                                await doBackup()
                            }
                        }else {
                            self.showModalCancel = true
                        }

                     
                    }, type: .primary, isExpanded: true)
                }
                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    browseFiles()
                }, type: .secondary, isExpanded: true)
                
            } else {
                if self.isDownloadingBackup() {
                    AppButton(title: "BACKUP_DOWNLOAD_STOP", onClick: {
                        stopBackupDownload()
                    }, type: .secondary, isExpanded: true)
                } else {
                    AppButton(title: "BACKUP_DOWNLOAD", onClick: {
                        downloadBackup()
                    }, type: .secondary, isExpanded: true)
                }
                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    browseFiles()
                }, type: .secondary, isExpanded: true)
            }
        }
        
    }
    
    func stopBackupDownload() {
        Task {
            do {
                try backupsService.stopBackupDownload()
            } catch {
                error.reportToSentry()
            }
        }
    }
    
    func downloadBackup() {
        if(backupsService.backupDownloadStatus == .InProgress) {
            let alert = NSAlert()
            let title = NSLocalizedString("BACKUP_DOWNLOAD_IN_PROGRESS_ALERT_TITLE", comment: "")
            let message = NSLocalizedString("BACKUP_DOWNLOAD_IN_PROGRESS_ALERT_MESSAGE", comment: "")
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
            return
        }
        
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let panelResponse = panel.runModal()
        if(panelResponse == .OK) {
            guard let url = panel.url else {
                return
            }
            Task {
                do {
                    try await backupsService.downloadBackup(device: device, downloadAt: url)
                } catch {
                    appLogger.error(["Error downloading backup", error])
                }
                
            }
        }
    }
    
    func selectFoldersAndStartBackup() {
        self.isEditingSelectedFolders = false
        self.showFolderSelector = true
    }
    
    func changeFolders() {
        self.isEditingSelectedFolders = true
        self.showFolderSelector = true
    }
    
    func fixMissingFolders() {
        self.isEditingSelectedFolders = true
        self.showFolderSelector = true
    }
    
    func browseFiles() {
        self.showBackupContentNavigator = true
    }
    
    private func doBackup() async {
        do {
            if(backupsService.foldersToBackup.isEmpty) {
                self.selectFoldersAndStartBackup()
            } else {
                try await self.backupsService.startBackup(onProgress: {progress in })
            }
            
        } catch {
            self.showErrorDialog(message: "BACKUP_ERROR_BACKING_UP")
        }
    }
    
    private func showErrorDialog(message: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func removeBackupDate(){
        UserDefaults.standard.removeObject(forKey: "INTERNXT_LAST_BACKUP_TIME_KEY")
    }
}

#Preview {
    BackupConfigView(
        numOfFolders: 16,
        backupsService: BackupsService(),
        backupUploadStatus: .constant(.InProgress),
        showStopBackupDialog: .constant(false),
        showDeleteBackupDialog: .constant(false),
        showFolderSelector: .constant(false),
        isEditingSelectedFolders: .constant(true),
        device: .constant(BackupsDeviceService.shared.getDeviceForPreview()),
        showBackupContentNavigator: .constant(false),
        backupManager: ScheduledBackupManager(backupsService: BackupsService())
    )
}
