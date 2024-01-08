//
//  FolderSelectorView.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 12/28/23.
//

import SwiftUI

enum FolderSelectorError: Error {
    case NotImplementedError
}

struct FolderSelectorView: View {

    @StateObject var backupsService: BackupsService
    let closeWindow: () -> Void
    @State private var isBackupButtonEnabled = false
    @State private var selectedIndex: Int?

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

            WidgetFolderList(folders: $backupsService.urls, selectedIndex: $selectedIndex)

            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            if let url = panel.url {
                                self.backupsService.urls.append(url)
                            }
                        }
                    }, type: .secondary, size: .SM)

                    AppButton(icon: .Minus, title: "", onClick: {
                        if let index = selectedIndex {
                            self.backupsService.urls.remove(at: index)
                            self.selectedIndex = nil
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
                            print("Error \(error.reportToSentry())")
                        }
                    }, type: .primary, size: .SM, isEnabled: $isBackupButtonEnabled)
                }
            }

        }
        .onChange(of: backupsService.urls, perform: { list in
            if list.count == 0 {
                self.isBackupButtonEnabled = false
            } else {
                self.isBackupButtonEnabled = true
            }
        })
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
    }

    private func doBackup() throws {
//        for i in 0..<urls.count {
//            activityManager.saveFoldernameToBackup(foldername: FoldernameToBackup(foldername: urls[i], status: .selected))
//        }
//        throw FolderSelectorError.NotImplementedError
    }
}

#Preview {
    FolderSelectorView(backupsService: BackupsService(), closeWindow: {})
}
