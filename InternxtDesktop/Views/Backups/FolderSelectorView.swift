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
    let closeWindow: () -> Void
    @State private var selectedId: String?

    private var foldersCountLabel: Text {
        if backupsService.foldersToBackup.count == 1 {
            return Text("BACKUP_SETTINGS_ONE_FOLDER")
        } else {
            return Text("BACKUP_SETTINGS_\("\(backupsService.foldersToBackup.count)")_FOLDERS")
        }
    }

    var body: some View {
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

            BackupsFolderListView(foldersToBackup: $backupsService.foldersToBackup, selectedId: $selectedId)

            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = true
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            for url in panel.urls {
                                do {
                                    let urls = backupsService.foldersToBackup.map { foldernToBackup in
                                        return foldernToBackup.url
                                    }
                                    if (!urls.contains(url)) {
                                        
                                        try self.backupsService.addFolderToBackup(url:url)
                                            
                                        
                                    }
                                } catch {
                                    error.reportToSentry()
                                    showErrorDialog(message: error.localizedDescription)
                                }
                            }
                        }
                    }, type: .secondary, size: .SM)

                    AppButton(icon: .Minus, title: "", onClick: {
                        if let selectedId = selectedId {
                            self.deleteFolder(selectedId: selectedId)
                        }
                    }, type: .secondary, size: .SM, isEnabled: backupsService.foldersToBackup.count != 0)
                }

                Spacer()

                HStack {
                    AppButton(title: "COMMON_CANCEL", onClick: {
                        withAnimation {
                            closeWindow()
                        }
                    }, type: .secondary, size: .SM)

                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                        doBackup()
                    }, type: .primary, size: .SM, isEnabled: !backupsService.foldersToBackup.isEmpty)
                }
            }

        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
        .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
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

    private func deleteFolder(selectedId: String) {
        Task {
            do {
                try await self.backupsService.removeFolderToBackup(id: selectedId)
                self.selectedId = nil
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
    FolderSelectorView(backupsService: BackupsService(), closeWindow: {})
}
