//
//  FolderSelectorView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

struct FolderSelectorView: View {

    @StateObject var backupsService: BackupsService
    let closeWindow: () -> Void
    @State private var selectedId: String?

    private var foldersCountLabel: Text {
        if backupsService.foldernames.count == 1 {
            return Text("BACKUP_SETTINGS_ONE_FOLDER")
        } else {
            return Text("BACKUP_SETTINGS_\("\(backupsService.foldernames.count)")_FOLDERS")
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

            BackupsFolderList(foldernames: $backupsService.foldernames, selectedId: $selectedId)

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
                                    let urls = backupsService.foldernames.map { foldername in
                                        return URL(string: foldername.url)
                                    }
                                    if (!urls.contains(url)) {
                                        try self.backupsService.addFoldernameToBackup(
                                          FoldernameToBackup(
                                              url: url.absoluteString,
                                              status: .selected
                                          )
                                        )
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
                            do {
                                try self.backupsService.removeFoldernameFromBackup(id: selectedId)
                                self.selectedId = nil
                            } catch {
                                error.reportToSentry()
                                showErrorDialog(message: error.localizedDescription)
                            }
                        }
                    }, type: .secondary, size: .SM, isEnabled: backupsService.foldernames.count != 0)
                }

                Spacer()

                HStack {
                    AppButton(title: "COMMON_CANCEL", onClick: {
                        withAnimation {
                            closeWindow()
                        }
                    }, type: .secondary, size: .SM)

                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                        do {
                            try doBackup()
                        } catch {
                            // show error in UI
                            showErrorDialog(message: error.localizedDescription)
                        }
                    }, type: .primary, size: .SM, isEnabled: backupsService.foldernames.count != 0)
                }
            }

        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
        .background(Color.Surface)
        .cornerRadius(10)
    }

    private func doBackup() throws {
        Task {
            try await self.backupsService.syncBackup()
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
