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
    var deviceName: String
    var isCurrentDevice: Bool
    var numOfFolders: Int
    var backupInProgress: Bool
    var lastUpdated: String?
    @StateObject var backupsService: BackupsService
    
    @Binding var showStopBackupDialog: Bool
    @Binding var showDeleteBackupDialog: Bool
    @Binding var showFolderSelector: Bool
    @State private var currentFrequency: UploadFrequencyEnum = .manually
    
    private var formattedDate: String {
        guard let lastUpdated, let lastUpdatedDate = Time.dateFromISOString(lastUpdated) else {
            return ""
        }
        return Time.stringDateFromDate(lastUpdatedDate, dateStyle: .long, timeStyle: .short)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppText("BACKUP_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray80)
            
            BackupStatusView(
                deviceName: self.deviceName,
                isCurrentDevice: self.isCurrentDevice,
                backupInProgress: self.backupInProgress,
                lastUpdated: formattedDate,
                progress: $backupsService.currentBackupProgress
            )
            
            BackupActionsView.frame(maxWidth: .infinity)
            
            if isCurrentDevice {
                VStack(alignment: .leading, spacing: 8) {
                    AppText("BACKUP_SELECTED_FOLDERS")
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)
                    
                    HStack(spacing: 10) {
                        AppButton(title: "BACKUP_CHANGE_FOLDERS", onClick: {
                            changeFolders()
                        }, type: .secondary)
                        
                        Text("BACKUP_\("\(numOfFolders)")_NUMBER_OF_FOLDERS_SELECTED")
                            .font(.SMRegular)
                            .foregroundColor(.Gray60)
                    }
                }
                .padding([.top], 12)
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
                }, type: .secondary)
            }
            .padding([.top], 12)
        }
        .padding([.vertical, .trailing], 20)
        .padding([.leading], 16)
    }
    
    var BackupActionsView: some View {
        HStack(spacing: 8) {
            if isCurrentDevice {
                if backupInProgress {
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
    
    func changeFolders() {
        self.showFolderSelector = true
    }
    
    func browseFiles() {
        URLDictionary.BACKUPS_WEB.open()
    }
    
    private func doBackup() async {
        do {
            if(backupsService.foldersToBackup.isEmpty) {
                self.changeFolders()
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
    BackupConfigView(deviceName: "Mac Mini M1", isCurrentDevice: true, numOfFolders: 16, backupInProgress: false, lastUpdated: "2016-06-05T16:56:57.019+01:00", backupsService: BackupsService(), showStopBackupDialog: .constant(false), showDeleteBackupDialog: .constant(false), showFolderSelector: .constant(false))
}
