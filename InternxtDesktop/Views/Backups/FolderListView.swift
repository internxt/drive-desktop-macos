//
//  BackupsFolderList.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/4/24.
//

import SwiftUI
struct FolderListItem: Identifiable {
    var id: String
    var name: String
    var type: String?
    var folderIsMissing: Bool?
    var uuid: String?
}



struct FolderListView<Empty: View>: View {
    @Environment(\.colorScheme) var colorScheme

    @Binding var items: [FolderListItem]
    @Binding var selectedId: String?
    @Binding var selectedUuid: String?
    @Binding var isLoading: Bool
    let onItemSingleTap: (FolderListItem) -> Void
    let onItemDoubleTap: (FolderListItem) -> Void
    var onEndReached: () async -> Void = {}
    var onMissingFolderURLLocated: (FolderListItem, URL) -> Void = {_,_ in }
    @ViewBuilder let empty: () -> Empty?
    private let minimumRowsToEnableScroll = 5
    @State private var isLoadingMoreContent = false
    
    private var axes: Axis.Set {
        return !isLoading ? .vertical : []
    }
    
    private func pendingRowsToDisplayUntilSpaceIsFilled() -> Int {
        let minimumRows = 10;
        let pendingRows = minimumRows - self.items.count
        
        return pendingRows
    }
    
    
    private func endReached() {
        if !isLoadingMoreContent {
            Task {
                await onEndReached()
                self.isLoadingMoreContent = false
            }
        }
    }
    
    var body: some View {
        if let empty = self.empty(), self.items.isEmpty && !self.isLoading {
            empty
        } else {
            VStack {
                ScrollView(axes) {
                    LazyVStack(spacing: 0) {
                        if self.isLoading, self.items.isEmpty {
                            ForEach(0..<10) { index in
                                FolderRowSkeleton(index: index)
                            }
                        } else {
                            ForEach(0..<self.items.count, id: \.self) { index in
                                FolderRow(item: self.items[index], index: index)
                            }
                            
                            HStack {}.onAppear{
                                endReached()
                            }
                            
                        }
                    }
                }
            }
            
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .cornerRadius(8.0)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.Gray10, lineWidth: 1)
            )
        }
    }
    
    // TODO: Move this outside of this view, it breaks the abstraction
    func locateMissingFolderToBackup(folderListItem: FolderListItem) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let panelResponse = panel.runModal()
        
        if panelResponse == .OK {
            guard let newURL = panel.url else {
                return
            }
            Task {
             onMissingFolderURLLocated (folderListItem, newURL)
            }
        }
        
    }
    
    func FolderRowSkeleton(index: Int) -> some View {
        return HStack(alignment: .center, spacing: 8) {
        }
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(getRowBackgroundColor(for: index))
        
    }
    
    
    func FolderRow(item: FolderListItem, index: Int) -> some View {
        let isSelected =  selectedId == item.id

        var fullname = item.name
        let type = item.type ?? "folder"
        if type != "folder" {
            fullname = fullname + ".\(type)"
        }
        return HStack(alignment: .center, spacing: 8) {
            
            Image(getIconNameForFileExtension(fileExtension: type)).resizable()
                .scaledToFit()
                .frame(height: 22)
            AppText(fullname)
                .font(.LGRegular)
                .foregroundColor(selectedId == item.id ? .white : .Gray80).lineLimit(1).truncationMode(.middle)
            Spacer()
            
            
             
             if item.folderIsMissing == true {
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
                            locateMissingFolderToBackup(folderListItem: item)
                        } , type: .secondary, size: .SM)
                    }
                    
                }
            }
        }
        
        .padding([.horizontal], 10)
        .frame( minWidth: 0,
                maxWidth: .infinity,
                minHeight: 36,
                maxHeight: .infinity,
                alignment: .center
        )
        .background( isSelected ? .Primary : getRowBackgroundColor(for: index))
        .gesture(
            onMultipleTaps(firstCount: 2, firstAction: {
                self.onItemDoubleTap(item)
            }, secondCount: 1, secondAction: {
                self.selectedId = item.id
                self.selectedUuid = item.uuid 
                self.onItemSingleTap(item)
            }
        ))
        
    }

    private func getRowBackgroundColor(for index: Int) -> Color {
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



#Preview {
    FolderListView(
        items: .constant([
        FolderListItem(
            id: "1",
            name: "FolderA",
            type: "folder",
            folderIsMissing: true
        ),
        FolderListItem(
            id: "2", name: "FolderB", type: "folder"
        ),
        FolderListItem(
            id: "3", 
            name: "file",
            type: "jpg"
        )]),
        selectedId: .constant(nil),
        selectedUuid: .constant(nil),
        isLoading: .constant(false),
        onItemSingleTap: {item in
            
        },
        onItemDoubleTap: {item in
            
        },
        empty: {
            AppText("This is empty")
        }
    )
}
