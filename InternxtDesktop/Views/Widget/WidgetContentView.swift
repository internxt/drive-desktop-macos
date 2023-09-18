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
    
    @Binding var activityEntries: [ActivityEntry]

    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading,spacing: 0) {
                ForEach(activityEntries) { activityEntry in
                   WidgetSyncEntryView(
                    filename: activityEntry.filename,
                    operationKind: activityEntry.kind,
                    status: activityEntry.status
                   )
                }.listRowInsets(EdgeInsets()).frame(maxWidth: .infinity)
            }.padding(.top, 8)
            
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
        WidgetContentView(activityEntries: .constant([]))
    }
}
