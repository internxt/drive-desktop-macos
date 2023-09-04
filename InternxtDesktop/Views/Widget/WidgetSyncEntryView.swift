//
//  WidgetSyncEntryView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 1/9/23.
//

import SwiftUI

enum WidgetSyncEntryOperationKind {
    case trash
    case delete
    case download
    case upload
    case move
}

enum WidgetSyncEntryStatus {
    case failed
    case finished
    case inProgress
}
struct WidgetSyncEntryView: View {
    private let filename: String
    private let operationKind: WidgetSyncEntryOperationKind
    private let status: WidgetSyncEntryStatus
    init(filename: String, operationKind: WidgetSyncEntryOperationKind, status: WidgetSyncEntryStatus) {
        self.filename = filename
        self.operationKind = operationKind
        self.status = status
    }
    var body: some View {
        VStack(alignment: .center, spacing: 0){
            HStack(alignment: .center, spacing: 10){
                Image(getFileExtensionIconName(filenameWithExtension: filename))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)
                    .shadow(color: .black.opacity(0.02), radius: 16, x: 0, y: 24)
                    .shadow(color: .black.opacity(0.02), radius: 12, x: 0, y: 16)
                    .shadow(color: .black.opacity(0.02), radius: 10, x: 0, y: 12)
                    .shadow(color: .black.opacity(0.02), radius: 8, x: 0, y: 8)
                    .shadow(color: .black.opacity(0.02), radius: 4, x: 0, y: 4)
                VStack(alignment: .leading){
                    AppText(filename)
                        .font(AppTextFont["SM/Medium"])
                        .foregroundColor(Color("Gray100"))
                    EntryStatusSubtitle
                }
                
                Spacer()
                EntryStatus
            }.padding(.horizontal, 12).frame(height: 56)
            Divider().foregroundColor(Color("Gray1"))
        }
        
    }
    
    @ViewBuilder
    var EntryStatusSubtitle: some View {
        switch self.operationKind {
        case .trash:
            AppText("OperationKindTrash").font(AppTextFont["XS/Medium"]).foregroundColor(Color("Gray50"))
        case .download:
            AppText("OperationKindDownloaded").font(AppTextFont["XS/Medium"]).foregroundColor(Color("Gray50"))
        case .upload:
            AppText("OperationKindUploaded").font(AppTextFont["XS/Medium"]).foregroundColor(Color("Gray50"))
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    var EntryStatus: some View {
        switch self.status {
        case .finished:
            AppIcon(iconName: .Check, size: 24, color: Color("GreenDark"))
        default:
            EmptyView()
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
