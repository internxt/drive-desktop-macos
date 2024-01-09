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

    var body: some View {
        VStack(spacing: 12) {

            HStack {
                AppText("BACKUP_SETTINGS_BACKUP_FOLDERS")
                    .font(.LGMedium)
                    .foregroundColor(.Gray100)

                Spacer()

                Text("BACKUP_SETTINGS_\("\(backupsService.urls.count)")_FOLDERS")
                    .font(.BaseRegular)
                    .foregroundColor(.Gray50)
            }

            WidgetFolderList(foldernames: $backupsService.foldernames, selectedId: $selectedId)

            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            if let url = panel.url {
                                do {
                                    try self.backupsService.addFoldernameToBackup(
                                        FoldernameToBackup(
                                            url: url.absoluteString,
                                            status: .selected
                                        )
                                    )
                                } catch {
                                    // show error in UI
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
                                // show error in UI
                                showErrorDialog(message: error.localizedDescription)
                            }
                        }
                    }, type: .secondary, size: .SM)
                    .disabled(self.backupsService.urls.count == 0)
                }

                Spacer()

                HStack {
                    AppButton(title: "COMMON_CANCEL", onClick: {
                        closeWindow()
                    }, type: .secondary, size: .SM)

                    AppButton(title: "COMMON_BACKUP_NOW", onClick: {
                        do {
                            try doBackup()
                        } catch {
                            // show error in UI
                            showErrorDialog(message: error.localizedDescription)
                        }
                    }, type: .primary, size: .SM, isEnabled: !backupsService.urls.isEmpty)
                }
            }

        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
    }

    private func doBackup() throws {
        throw AppError.notImplementedError
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
