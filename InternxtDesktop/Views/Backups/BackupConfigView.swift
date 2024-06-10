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
    @Binding var backupStatus: BackupStatus
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @Binding var showFolderSelector: Bool
    @Binding var isEditingSelectedFolders: Bool
    @Binding var device: Device
    
    @State var backupManager: ScheduledBackupManager = ScheduledBackupManager()
    @ObservedObject var appSettings = AppSettings.shared
    @State private var selectedFrequency: BackupFrequencyEnum = AppSettings.shared.selectedBackupFrequency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            
            BackupStatusView(
                backupStatus: self.$backupStatus,
                device: self.$device,
                progress: $backupsService.currentBackupProgress
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
                            }, type: .secondary)
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
                            }, type: .secondary)
                            
                            Text("BACKUP_\("\(numOfFolders)")_NUMBER_OF_FOLDERS_SELECTED")
                                .font(.SMRegular)
                                .foregroundColor(.Gray60)
                        }
                    }
                    
                }
                .padding([.top], 12)
            }
           
            BackupFrequencySelectorView(currentFrequency: $appSettings.selectedBackupFrequency, onClick: { option in
                ScheduledBackupManager.shared.startBackupTimer(frequency: option)
            })
            
            VStack(alignment: .leading, spacing: 8) {
                AppText("BACKUP_UPLOAD_DELETE_BACKUP")
                    .font(.SMMedium)
                    .foregroundColor(.Gray80)
                
                AppText("BACKUP_UPLOAD_DELETE_BACKUP_CONTENT")
                    .font(.SMRegular)
                    .foregroundColor(.Gray50)
                
                AppButton(title: "BACKUP_UPLOAD_DELETE_BACKUP", onClick: {
                    showDeleteBackupDialog = true
                }, type: .secondary)
            }
            .padding([.top], 12)
        }
        .padding([.vertical, .trailing], 20)
        .padding([.leading], 16)
    }
    
    var BackupActionsView: some View {
        HStack(spacing: 8) {
            if self.device.isCurrentDevice {
                if self.backupStatus == .InProgress {
                    AppButton(title: "BACKUP_STOP_BACKUP", onClick: {
                        showStopBackupDialog = true
                    }, type: .primary, isExpanded: true)
                } else {
                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                        Task {
                            await doBackup()
                        }
                    }, type: .primary, isExpanded: true)
                }
                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    browseFiles()
                }, type: .secondary, isExpanded: true)
            } else {
                AppButton(title: "BACKUP_BROWSE_FILES", onClick: {
                    browseFiles()
                }, type: .secondary, isExpanded: true)
                Spacer().frame(maxWidth: .infinity)
            }
        }
        
    }
    
    func downloadBackup() throws {
        throw AppError.notImplementedError
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
        URLDictionary.BACKUPS_WEB.open()
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
    
}

#Preview {
    BackupConfigView(
        numOfFolders: 16,
        backupsService: BackupsService(),
        backupStatus: .constant(.InProgress),
        showStopBackupDialog: .constant(false),
        showDeleteBackupDialog: .constant(false),
        showFolderSelector: .constant(false),
        isEditingSelectedFolders: .constant(true),
        device: .constant(BackupsDeviceService.shared.getDeviceForPreview())
    )
}
