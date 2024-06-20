//
//  WidgetBackupDownloadEntryView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/6/24.
//

import Foundation
import SwiftUI


struct WidgetBackupOperationEntryView: View {
    let deviceName: String
    let status: ActivityEntryStatus
    @Binding var downloadedItems: Int64
    
    private func getDisplayName() -> String {
        return "Backup — \"\(deviceName)\""
    }
    var body: some View {
        VStack(alignment: .center, spacing: 0){
            HStack(alignment: .center, spacing: 10){
                Image("backup_folder")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .shadow(color: .black.opacity(0.02), radius: 16, x: 0, y: 24)
                    .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 16)
                    .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 12)
                    .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 4)
                VStack(alignment: .leading){
                    Text(verbatim: getDisplayName())
                        .font(.SMMedium)
                        .foregroundColor(.Gray100)
                        .lineLimit(1)
                        .help(getDisplayName())
                    EntryStatusSubtitle
                }
                
                Spacer()
                EntryStatus
            }.padding(.horizontal, 12).frame(height: 56)
            Divider().foregroundColor(.Gray1).frame(height:1)
        }
        
    }
    
    @ViewBuilder
    var EntryStatusSubtitle: some View {
        Text("\(String(downloadedItems))_BACKUP_DOWNLOADED_ITEMS").font(.XSMedium)
            .foregroundColor(.Gray50)
    }

    @ViewBuilder
    var EntryStatus: some View {
        switch self.status {
        case .inProgress:
            HStack(alignment:.center, content: {
                ProgressView().controlSize(.small)
            }).frame(width: 24)
            
        case .finished:
            AppIcon(iconName: .Check, size: 24, color: .GreenDark)
        default:
            EmptyView()
        }
    }
}

struct WidgetBackupOperationEntryView_Previews: PreviewProvider {
    static var previews: some View {
        VStack{
            WidgetBackupOperationEntryView(deviceName: "Mac Mini M1", status: .inProgress, downloadedItems: .constant(5))
            
        }.frame(width: 330).background(Color("Surface"))
        
    }
}
