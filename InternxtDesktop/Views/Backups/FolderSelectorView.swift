//
//  FolderSelectorView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct FolderSelectorView: View {
    
    @Environment(\.colorScheme) var colorScheme
    @StateObject var backupsService: BackupsService
    @State private var showModalCancel = false

    let closeWindow: () -> Void
    @State private var folderToBackupId: String?
    @Binding var isEditingSelectedFolders: Bool
    private var foldersCountLabel: Text {
        if backupsService.foldersToBackup.count == 1 {
            return Text("BACKUP_SETTINGS_ONE_FOLDER")
        } else {
            return Text("BACKUP_SETTINGS_\("\(backupsService.foldersToBackup.count)")_FOLDERS")
        }
    }
    
    func handleMissingFolderURLLocated(folderListItem: FolderListItem, newURL: URL) -> Void {

        Task{
            do {
                try backupsService.updateFolderToBackupURL(folderId: folderListItem.id, newURL: newURL)
                DispatchQueue.main.async {
                    backupsService.loadFoldersToBackup()
                }
            } catch {
                appLogger.error(["Failed to update folder to backup URL", error])
            }
        }
    }
    
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let panelResponse = panel.runModal()
        if panelResponse == .OK {
            for url in panel.urls {
                do {
                    let urls = backupsService.foldersToBackup.map { folderToBackup in
                        return folderToBackup.url
                    }
                    
                    let urlAlreadyIncluded = urls.contains(url)
                    
                    if (!urlAlreadyIncluded) {
                        try self.backupsService.addFolderToBackup(url:url)
                    }
                } catch {
                    error.reportToSentry()
                    showErrorDialog(message: error.localizedDescription)
                }
            }
        }
    }
    
    func getSelectorItems() -> Binding<[FolderListItem]> {
        let items = $backupsService.foldersToBackup.wrappedValue.map{folder in
            FolderListItem(id: folder.id, name:folder.name, type: nil, folderIsMissing: folder.folderIsMissing())
        }
        return Binding.constant(items)
    }

    var body: some View {
        ZStack {
        VStack(spacing: 12) {
            
            HStack {
                AppText("BACKUP_SETTINGS_BACKUP_FOLDERS")
                    .font(.LGMedium)
                    .foregroundColor(.Gray100)
                
                Spacer()
                
                foldersCountLabel
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
            }
            
            FolderListView(
                items: self.getSelectorItems(),
                selectedId: $folderToBackupId,
                selectedUuid: .constant(nil), isLoading: .constant(false),
                onItemSingleTap: {item in},
                onItemDoubleTap: {item in},
                onMissingFolderURLLocated: handleMissingFolderURLLocated,
                empty: {
                    VStack {
                        AppText("BACKUP_SETTINGS_ADD_FOLDERS")
                            .font(.BaseRegular)
                            .foregroundColor(.Gray50)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.Gray10, lineWidth: 1)
                    )
                }
            )
            
            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: selectFolder, type: .secondary, size: .SM)
                    
                    AppButton(icon: .Minus, title: "", onClick: {
                        if let folderToBackupId = folderToBackupId {
                            self.deleteFolder(folderToBackupId: folderToBackupId)
                        }
                    }, type: .secondary, size: .SM, isEnabled: backupsService.foldersToBackup.count != 0)
                }
                
                Spacer()
                
                HStack {
                    AppButton(title: "COMMON_CANCEL", onClick: {
                        withAnimation {
                            Task {
                                await backupsService.restoreFolderToBackup()
                            }
                            
                            closeWindow()
                        }
                    }, type: .secondary, size: .SM)
                    if isEditingSelectedFolders {
                        AppButton(title: "COMMON_SAVE", onClick: {
                            closeWindow()
                        }, type: .primary, size: .SM)
                    } else {
                        AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                            if backupsService.currentBackupState == .active {
                                doBackup()
                            }else {
                                self.showModalCancel = true
                            }
                        }, type: .primary, size: .SM, isEnabled: !backupsService.foldersToBackup.isEmpty)
                    }
                    
                }
            }
            
        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
        .onAppear{
            Task{
                await backupsService.initFolderToBackup()
            }
        }
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

    private func doBackup() {
        Task {
            do {
                closeWindow()
                try await self.backupsService.startBackup( onProgress: {progress in
                })
            } catch {
                self.showErrorDialog(message: "BACKUP_ERROR_BACKING_UP")
            }
        }
    }

    private func deleteFolder(folderToBackupId: String) {
        Task {
            do {
                try await self.backupsService.removeFolderToBackup(folderToBackupId: folderToBackupId)
                self.folderToBackupId = nil
            } catch {
                error.reportToSentry()
                showErrorDialog(message: error.localizedDescription)
            }
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
    FolderSelectorView(backupsService: BackupsService(), closeWindow: {}, isEditingSelectedFolders: .constant(false))
}
