//
//  WidgetSyncEntryView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import SwiftUI


struct WidgetSyncEntryView: View {
    let filename: String
    let operationKind: ActivityEntryOperationKind
    let status: ActivityEntryStatus
    
    var body: some View {
        VStack(alignment: .center, spacing: 0){
            HStack(alignment: .center, spacing: 10){
                Image(operationKind == .backupDownload ? "backup_folder" : getFileExtensionIconName(filenameWithExtension: filename))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .shadow(color: .black.opacity(0.02), radius: 16, x: 0, y: 24)
                    .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 16)
                    .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 12)
                    .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 4)
                VStack(alignment: .leading){
                    Text(verbatim: filename)
                        .font(.SMMedium)
                        .foregroundColor(.Gray100)
                        .lineLimit(1)
                        .help(filename)
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
        switch self.operationKind {
        case .backupDownload:
            switch status {
            case .inProgress:
                AppText("SYNC_ENTRY_KIND_DOWNLOADING").font(.XSMedium).foregroundColor(.Gray50)
            case .finished:
                AppText("SYNC_ENTRY_KIND_DOWNLOADED").font(.XSMedium).foregroundColor(.Gray50)
            case .failed:
                AppText("SYNC_ENTRY_KIND_FAILED").font(.XSMedium).foregroundColor(.Red)
            }
        case .trash:
            AppText("SYNC_ENTRY_KIND_TRASHED").font(.XSMedium).foregroundColor(.Gray50)
        case .download:
            switch status {
            case .inProgress:
                AppText("SYNC_ENTRY_KIND_DOWNLOADING").font(.XSMedium).foregroundColor(.Gray50)
            case .finished:
                AppText("SYNC_ENTRY_KIND_DOWNLOADED").font(.XSMedium).foregroundColor(.Gray50)
            case .failed:
                AppText("SYNC_ENTRY_KIND_FAILED").font(.XSMedium).foregroundColor(.Red)
            }
        case .upload:
            switch status {
            case .inProgress:
                AppText("SYNC_ENTRY_KIND_UPLOADING").font(.XSMedium).foregroundColor(.Gray50)
            case .finished:
                AppText("SYNC_ENTRY_KIND_UPLOADED").font(.XSMedium).foregroundColor(.Gray50)
            case .failed:
                AppText("SYNC_ENTRY_KIND_FAILED").font(.XSMedium).foregroundColor(.Red)
            }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    var EntryStatus: some View {
        switch self.status {
        case .finished:
            AppIcon(iconName: .Check, size: 24, color: .GreenDark)
        case .inProgress:
            ProgressView()
                .scaleEffect(0.7)
                .frame(width: 24, height: 24)
        case .failed:
            AppIcon(iconName: .WarningCircle, size: 24, color: .Red)
        }
    }
}

struct WidgetSyncEntry_Previews: PreviewProvider {
    static var previews: some View {
        VStack{
            WidgetSyncEntryView(filename: "Frontend_web.fig", operationKind: .trash, status: .finished)
            WidgetSyncEntryView(filename: "demo.mp4", operationKind: .download, status: .finished)
            WidgetSyncEntryView(filename: "doggo.jpg", operationKind: .upload, status: .finished)
        }.frame(width: 330).background(Color("Surface"))
        
    }
}
