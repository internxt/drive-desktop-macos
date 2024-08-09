//
//  WidgetContentView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import FileProvider
import RealmSwift
struct WidgetContentView: View {
    @EnvironmentObject var backupsService: BackupsService
    @Binding var activityEntries: [ActivityEntry]

    func backupDownloadInProgress() -> Bool {
        backupsService.backupDownloadStatus == .InProgress
    }
    

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading,spacing: 0) {
                if(backupDownloadInProgress()) {
                    WidgetBackupOperationEntryView(deviceName: backupsService.deviceDownloading?.plainName ?? "Device", status: .inProgress, downloadedItems: $backupsService.backupDownloadedItems)
                }
                
                ForEach(backupsService.backupsItemsInprogress) { item in
                    WidgetBackupOperationEntryView(deviceName: item.device.plainName ?? "Device", status: .inProgress, downloadedItems: .constant(1))
                }
                ForEach(activityEntries) { activityEntry in
                   WidgetSyncEntryView(
                    filename: activityEntry.filename,
                    operationKind: activityEntry.kind,
                    status: activityEntry.status
                   )
                }.listRowInsets(EdgeInsets()).frame(maxWidth: .infinity)
            }.padding(.top, 0)
            
        }
        .padding(.horizontal, 0)
        .listStyle(.plain)
        .ifAvailable {
            if #available(macOS 13.0, *) {
                $0.scrollContentBackground(.hidden)
            }
        }
        
    }
}

struct WidgetContentView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            WidgetContentView(activityEntries: .constant([
                ActivityEntry(filename: "file123.png", kind: .download, status: .finished),
                ActivityEntry(filename: "video2.mp4", kind:.trash, status: .finished),
                ActivityEntry(filename: "image.jpg", kind:.trash, status: .finished),
                ActivityEntry(filename: "dog.mp4", kind:.trash, status: .finished),
                ActivityEntry(filename: "audio.mp3", kind:.trash, status: .finished),
                ActivityEntry(filename: "design.fig", kind:.trash, status: .finished)])).environmentObject(BackupsService())
        }.frame(maxWidth: 400,maxHeight: 600)
        
    }
}
