//
//  WidgetContentView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI
import FileProvider

struct WidgetContentView: View {
    var body: some View {
        
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading,spacing: 0) {
                ForEach([] as [DomainSyncEntry]) { syncEntry in
                    WidgetSyncEntryView(filename: syncEntry.filename, operationKind: .upload, status: .finished)
                }.listRowInsets(EdgeInsets()).frame(maxWidth: .infinity)
            }.padding(.top, 8)
            
        }
        .padding(.horizontal, 0)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)

            
        
    }
}

struct WidgetContentView_Previews: PreviewProvider {
    static var previews: some View {
        WidgetContentView()
    }
}
