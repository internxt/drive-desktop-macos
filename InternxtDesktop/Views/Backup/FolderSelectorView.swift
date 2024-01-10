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

    let closeWindow: () -> Void
    @State private var isBackupButtonEnabled = false
    @State private var foldernames: [String] = []
    @State private var urls: [String] = []
    @State private var selectedIndex: Int?

    private var foldersCountLabel: Text {
        if urls.count == 1 {
            return Text("BACKUP_SETTINGS_ONE_FOLDER")
        } else {
            return Text("BACKUP_SETTINGS_\("\(urls.count)")_FOLDERS")
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

            WidgetFolderList(folders: $foldernames, selectedIndex: $selectedIndex)

            HStack {
                HStack(spacing: 8) {
                    AppButton(icon: .Plus, title: "", onClick: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseDirectories = true
                        panel.canChooseFiles = false
                        if panel.runModal() == .OK {
                            if let url = panel.url {
                                let foldername = url.lastPathComponent
                                self.urls.append(url.absoluteString)
                                self.foldernames.append(foldername)
                            }
                        }
                    }, type: .secondary, size: .SM)

                    AppButton(icon: .Minus, title: "", onClick: {
                        if let index = selectedIndex {
                            self.urls.remove(at: index)
                            self.foldernames.remove(at: index)
                            self.selectedIndex = nil
                        }
                    }, type: .secondary, size: .SM, isEnabled: self.foldernames.count != 0)
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
                            print("Error \(error.reportToSentry())")
                        }
                    }, type: .primary, size: .SM, isEnabled: self.foldernames.count != 0)
                }
            }

        }
        .frame(width: 480, height: 380, alignment: .top)
        .padding(20)
        .background(Color.Surface)
        .cornerRadius(10)
    }

    private func doBackup() throws {
        throw FolderSelectorError.NotImplementedError
    }
}

#Preview {
    FolderSelectorView(closeWindow: {})
}
