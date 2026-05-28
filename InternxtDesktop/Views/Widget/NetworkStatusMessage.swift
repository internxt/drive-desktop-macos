//
//  NetworkStatusMessage.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/8/24.
//

import SwiftUI

struct NetworkStatusMessage: View {
    @Binding var status: NetworkStatus
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            HStack(alignment: .center, spacing: 0) {
                DisplayStatus()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 0)
            .frame(maxWidth: .infinity, minHeight: 40, maxHeight: 40, alignment: .leading)
        }.background(Color.Gray5)
    }
    
    func DisplayStatus() -> some View {
        
        
        return HStack(alignment: .center, spacing: 8){
            ZStack {
                //Circle().foregroundColor(.Gray10).frame(height: 22 )
                if status == .notConnected {
                    AppIcon(iconName: .WifiNone, size: 20, color: .Gray40)
                }
                
                if status == .poor {
                    AppIcon(iconName: .WifiMedium, size: 20, color: .Gray40)
                }
            }.padding(2)
            
            if status == .notConnected {
                VStack(alignment: .leading) {
                    AppText("NETWORK_CONNECTION_NONE_TITLE").font(.XSMedium)
                    AppText("NETWORK_CONNECTION_NONE_SUBTITLE").font(.XSRegular).foregroundColor(.Gray50)
                }
                
            }
            
            if status == .poor {
                VStack(alignment: .leading) {
                    AppText("NETWORK_CONNECTION_SLOW_TITLE").font(.XSMedium)
                    AppText("NETWORK_CONNECTION_SLOW_SUBTITLE").font(.XSRegular).foregroundColor(.Gray50)
                }
                
            }
            
            
        }
    }
}

#Preview {
    VStack {
        NetworkStatusMessage(status: .constant(.notConnected))
        NetworkStatusMessage(status: .constant(.poor))
    }
    
}
