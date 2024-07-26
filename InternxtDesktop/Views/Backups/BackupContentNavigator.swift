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
    @StateObject var viewModel = ViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    
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
            HStack {
                Breadcrumbs
                Spacer()
            }
            FolderListView(
                items: getFolderListItems(),
                selectedId: $selectedId,
                isLoading: $viewModel.loadingItems,
                onItemDoubleTap: {item in
                    navigateToFolder(item: item)
                },
                empty: {
                    AppText("123")
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
                }, type: .primary, size: .MD)
                
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
    
    
}


#Preview {
    BackupContentNavigator(device: BackupsDeviceService.shared.getDeviceForPreview() , onClose: {})
}
