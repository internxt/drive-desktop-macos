//
//  BackupContentNavigator.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 25/7/24.
//

import Foundation
import SwiftUI


struct BackupContentNavigator: View {
    let device: Device
    let onClose: () -> Void
    @State var selectedId: String? = nil
    @State var currentFolderId: String? = nil
    @StateObject var viewModel = ViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedFolderListItem: FolderListItem? = nil
    @StateObject var backupsService: BackupsService
    
    func getBreadcrumbsLevels() -> Binding<[AppBreadcrumbLevel]> {
        let levels: [AppBreadcrumbLevel] = $viewModel.navigationLevels.wrappedValue.map{level in
            AppBreadcrumbLevel(id: level.id, name: level.name)
        }
        
        return Binding(get: {
            return levels
        }, set: {_ in})
    }
    var Breadcrumbs: some View {
        AppBreadcrumbs(
            onLevelTap: {level in
                self.selectedFolderListItem = nil
                self.currentFolderId = level.id
                navigateToFolder(
                    item: FolderListItem(id: level.id, name: level.name, type: "folder")
                )
            },
            levels: getBreadcrumbsLevels()
        )
        
    }
    
    func navigateToFolder(item: FolderListItem) {
        Task {
            if let bucketId = device.bucket, let folderId = Int(item.id) {
                try await viewModel.loadFolderContent(folderName: item.name, folderId:folderId, bucketId: bucketId)
            }
            
        }
    }
    
    func handleOnEndOfListReached() async {
        Task {
            if let bucketId = device.bucket, let folderIdStr = currentFolderId, let folderId = Int(folderIdStr) {
                try? await viewModel.loadMoreForFolderId(folderId: folderId, bucketId: bucketId)
            }
        }
        
    }
    
    func getFolderListItems() -> Binding<[FolderListItem]> {
        
        let current = $viewModel.currentItems.wrappedValue
        
        
        return Binding<[FolderListItem]>(get: {
            current.map{ item in
                FolderListItem(id: item.id, name: item.name, type: item.type)
            }
        }, set: {_ in })
    }
    var body: some View {
        VStack {
            
            HStack(spacing: 0) {
                Breadcrumbs
                Spacer()
            }.frame(alignment: .leading)
            FolderListView(
                items: getFolderListItems(),
                selectedId: $selectedId,
                isLoading: $viewModel.loadingItems,
                
                onItemSingleTap: {item in
                    self.selectedFolderListItem = item
                },
                onItemDoubleTap: {item in
                    self.selectedFolderListItem = nil
                    if item.type == "folder" {
                        self.currentFolderId = item.id
                        navigateToFolder(item: item)
                    } else {
                        // Noop, files have no action here
                    }
                },
                onEndReached: handleOnEndOfListReached,
                empty: {
                    
                    VStack {
                        if (viewModel.folderError != nil) {
                            AppText("COMMON_FOLDER_LOAD_ERROR")
                                .font(.BaseRegular)
                                .foregroundColor(.Gray50)
                                .multilineTextAlignment(.center)
                        } else {
                            AppText("COMMON_FOLDER_EMPTY")
                                .font(.BaseRegular)
                                .foregroundColor(.Gray50)
                                .multilineTextAlignment(.center)
                        }
                        
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cornerRadius(8.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.Gray10, lineWidth: 1)
                    )
                }
            ).frame(maxHeight: .infinity)
            HStack {
                Spacer()
                AppButton(title: "COMMON_CANCEL", onClick: {
                    withAnimation {
                        onClose()
                    }
                }, type: .secondary, size: .MD)
                AppButton(title: "COMMON_DOWNLOAD", onClick: {
                    self.downloadItem()
                }, type: .primary, size: .MD, isEnabled: viewModel.folderError == nil)
                
            }
        }.frame(width: 480, height: 380, alignment: .top)
            .padding(20)
            .background(colorScheme == .dark ? Color.Gray1 : Color.white)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
            .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
            .onAppear{
                Task {
                    if let bucketId = device.bucket {
                        try await viewModel.loadFolderContent(folderName: device.plainName ?? device.name ?? "Unknown", folderId:device.id, bucketId: bucketId)
                    }
                    
                }
            }
    }
    
    private func downloadItem() {

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        let panelResponse = panel.runModal()
        if(panelResponse == .OK) {
            guard let url = panel.url else {
                return
            }
            
            
            Task {
                do {
                    // download root folder
                    let currentLevelIsRoot = viewModel.navigationLevels.count == 1
                    let notSelectedFolderOrFile = selectedFolderListItem == nil && selectedId == nil
                    if currentLevelIsRoot && notSelectedFolderOrFile {
                        if(backupsService.backupDownloadStatus == .InProgress) {
                            let title = NSLocalizedString("BACKUP_DOWNLOAD_IN_PROGRESS_ALERT_TITLE", comment: "")
                            let message = NSLocalizedString("BACKUP_DOWNLOAD_IN_PROGRESS_ALERT_MESSAGE", comment: "")
                            showAlert(message: title, informativeText: message)
                            return
                        }
                        try await backupsService.downloadBackup(device: device, downloadAt: url)
                    } else if let selectedFolderListItem = selectedFolderListItem {
                        guard let selectedId = selectedId else { return }
                        
                        if selectedFolderListItem.type == "folder" {
                            try await backupsService.downloadFolderBackup(device: device, downloadAt: url, folderId: selectedId)
                        } else {
                            try await backupsService.downloadFileBackup(device: device, downloadAt: self.getURLForItem(baseURL: url, itemName: selectedFolderListItem.name,itemType: selectedFolderListItem.type), fileId: selectedId)
                        }
                    } else if let selectedId = selectedId {
                        try await backupsService.downloadFolderBackup(device: device, downloadAt: url, folderId: selectedId)
                    }
                    
                } catch {
                    error.reportToSentry()
                    showAlert(message: error.localizedDescription, style: .warning)
                }
                
            }
            
            onClose()
        }
    }
    
    private func getURLForItem(baseURL: URL, itemName: String, itemType: String? = nil) -> URL {
        let type: String = (itemType != nil) ? ".\(itemType!)" : ""
        
        return baseURL.appendingPathComponent("\(itemName)\(type)")
    }
    
    
    func showAlert(message: String, informativeText: String? = nil, style: NSAlert.Style = .informational, buttonTitle: String = "OK") {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = informativeText ?? ""
        alert.alertStyle = style
        alert.addButton(withTitle: buttonTitle)
        alert.runModal()
    }
    
}


#Preview {
    BackupContentNavigator(device: BackupsDeviceService.shared.getDeviceForPreview() , onClose: {}, backupsService: BackupsService())
}
