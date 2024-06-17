//
//  BackupsFolderList.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/4/24.
//

import SwiftUI

struct BackupsFolderListView: View {

    @Environment(\.colorScheme) var colorScheme
    @Binding var foldersToBackup: [FolderToBackup]
    @Binding var selectedId: String?
    let onMissingFolderURLLocated: (FolderToBackup, URL) -> Void
    var body: some View {
        if self.foldersToBackup.isEmpty {
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
        } else {
            VStack {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<self.foldersToBackup.count, id: \.self) { index in
                            FolderRow(index: index)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .cornerRadius(8.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.Gray10, lineWidth: 1)
            )
        }
    }
    
    func locateMissingFolderToBackup(folderToBackupMissing: FolderToBackup) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let panelResponse = panel.runModal()
        
        if panelResponse == .OK {
            guard let newURL = panel.url else {
                return
            }
            Task {onMissingFolderURLLocated(folderToBackupMissing, newURL)}
        }
        
    }
    
    func FolderRow(index: Int) -> some View {
        let folderToBackup = self.foldersToBackup[index];
        
        return HStack(alignment: .center, spacing: 8) {
            Image("folder")
            AppText(folderToBackup.url.lastPathComponent.removingPercentEncoding ?? "Unknown folder")
                .font(.LGRegular)
                .foregroundColor(selectedId == self.foldersToBackup[index].id ? .white : .Gray80)
                .padding([.vertical], 10)
            
            Spacer()
            if folderToBackup.folderIsMissing() {
                HStack(spacing: 4) {
                    ZStack {
                        Color.white.ignoresSafeArea().frame(width:12, height:12).clipShape(RoundedRectangle(cornerRadius: 100))
                        Image("warning-circle-fill")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width:16, height: 16)
                            .foregroundColor(.Red)
                    }
                    HStack(spacing:8) {
                        AppText("BACKUP_MISSING_FOLDER_ERROR").font(.XSRegular).foregroundColor(.Red)
                        AppButton(title: "BACKUP_LOCATE_FOLDER", onClick: {
                            locateMissingFolderToBackup(folderToBackupMissing: folderToBackup)
                        } , type: .secondary)
                    }
                    
                }
            }
        }
        .padding([.horizontal], 10)
        .background(getRowBackgroundColor(for: index))
        .gesture(
            onMultipleTaps(firstCount: 2, firstAction: {
                self.openFolderInFinder(url: folderToBackup.url)
            }, secondCount: 1, secondAction: {
                self.selectedId = folderToBackup.id
            }
                          )
        )
    }

    private func getRowBackgroundColor(for index: Int) -> Color {
        if selectedId == foldersToBackup[index].id {
            return .Primary
        }

        if index % 2 == 0 {
            return .Gray1
        }

        if colorScheme == .dark {
            return .Gray5
        }

        return .white
    }

    private func openFolderInFinder(url: URL) {
        NSWorkspace.shared.open(url)
    }
}
