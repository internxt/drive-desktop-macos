//
//  AppSettingsManagerView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/11/23.
//

import SwiftUI

struct AppSettingsManagerView<Content: View>: View {
    private let content: Content
    
    @ObservedObject private var settings: AppSettings
    public init(content: () -> Content) {
       self.content = content()
        self.settings = AppSettings.shared
     }

     

     public var body: some View {
       content
        .environment(\.locale,settings.local)
        .id(settings.uuid)
        .environmentObject(settings)
     }
}

struct AppSettingsManagerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AppSettingsManagerView {
                AppText("SETTINGS_LEARN_MORE")
            }
            AppSettingsManagerView {
                AppText("SETTINGS_LEARN_MORE")
            }
            AppSettingsManagerView {
                AppText("SETTINGS_LEARN_MORE")
            }
        }.frame(width: 300, height: 200)
        
    }
}
