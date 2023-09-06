//
//  StartOnLaunchView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI
import LaunchAtLogin
struct StartOnLaunchView: View {
    @State var willStartOnLaunch: Bool = LaunchAtLogin.isEnabled
    var body: some View {
        VStack(alignment: .leading,spacing:0) {
            AppCheckbox(label: "StartOnLaunch", checked: $willStartOnLaunch)
            .onChange(of: willStartOnLaunch, perform: {willStartOnLaunch in
                LaunchAtLogin.isEnabled = willStartOnLaunch
            })
        }
        
    }
}

struct StartOnLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        StartOnLaunchView()
    }
}
