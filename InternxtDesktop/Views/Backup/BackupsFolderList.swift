//
//  BackupsFolderList.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/4/24.
//

import SwiftUI

struct BackupsFolderList: View {

    @Environment(\.colorScheme) var colorScheme
    @Binding var foldersToBackup: [FolderToBackup]
    @Binding var selectedId: String?

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
                    .inset(by: -0.5)
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
                    .inset(by: -0.5)
                    .stroke(Color.Gray10, lineWidth: 1)
            )
        }
    }
    
    func FolderRow(index: Int) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Image("folder")
            
            AppText(self.foldersToBackup[index].url.lastPathComponent.removingPercentEncoding ?? "Unknown folder")
                .font(.LGRegular)
                .foregroundColor(selectedId == self.foldersToBackup[index].id ? .white : .Gray80)
                .padding([.vertical], 10)
            
            Spacer()
        }
        .padding([.horizontal], 10)
        .background(getRowBackgroundColor(for: index))
        .gesture(
            onMultipleTaps(firstCount: 2, firstAction: {
                self.openFolderInFinder(url: self.foldersToBackup[index].url)
            }, secondCount: 1, secondAction: {
                self.selectedId = self.foldersToBackup[index].id
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
