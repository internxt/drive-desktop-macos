//
//  WidgetFolderList.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/4/24.
//

import SwiftUI

struct WidgetFolderList: View {

    @Environment(\.colorScheme) var colorScheme
    @Binding var folders: [String]
    @Binding var urls: [String]
    @Binding var selectedIndex: Int?

    var body: some View {
        if folders.count == 0 {
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
                        ForEach(0..<folders.count, id: \.self) { index in
                            HStack(alignment: .center, spacing: 8) {
                                Image("folder")

                                AppText(folders[index])
                                    .font(.LGRegular)
                                    .foregroundColor(selectedIndex == index ? .white : .Gray80)
                                    .padding([.vertical], 10)

                                Spacer()
                            }
                            .padding([.horizontal], 10)
                            .background(getRowBackgroundColor(for: index))
                            .onTapGesture(count: 2, perform: {
                                self.openFolderInFinder(url: urls[index])
                            })
                            .onTapGesture(count: 1, perform: {
                                self.selectedIndex = index
                            })
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

    private func getRowBackgroundColor(for index: Int) -> Color {
        if selectedIndex == index {
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

    private func openFolderInFinder(url: String) {
        let safeUrl = URL(fileURLWithPath: url.replacingOccurrences(of: "file:///", with: "/"), isDirectory: true)
        NSWorkspace.shared.open(safeUrl)
    }
}
