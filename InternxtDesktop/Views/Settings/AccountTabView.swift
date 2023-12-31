//
//  AccountTabView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI

struct AccountTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var usageManager: UsageManager
    
    var body: some View {
        if let user = authManager.user {
            VStack(alignment: .leading, spacing: 32) {
                VStack {
                    HStack(alignment: .center, spacing: 16) {
                        AppAvatar( size: 48, font: .XLSemibold, avatarURL: user.avatar)
                        VStack(alignment: .leading, spacing: 0) {
                            AppText("\(user.name) \(user.lastname)")
                                .font(.LGMedium)
                                .foregroundColor(Color.Gray100)
                            Text(verbatim: "\(user.email)")
                                .font(.SMRegular)
                                .foregroundColor(Color.Gray60)
                                .lineLimit(1)
                                .help(user.email)
                        }
                        Spacer()
                        AppButton(title: "COMMON_LOGOUT", onClick: handleLogout, type: .secondary, size: .MD )
                    }
                }
                
                .frame(maxWidth: .infinity, alignment: .topLeading)
                AccountUsageView()
            }.padding(20).frame(maxWidth: .infinity)
        } else {
            AnyView(EmptyView())
        }
       
        
       
    }
    
    func handleLogout() {
        do {
            try authManager.signOut()
        } catch {
            error.reportToSentry()
        }
        
    }
}

struct AccountTabView_Previews: PreviewProvider {
    static var previews: some View {
        AccountTabView()
            .environmentObject(AuthManager())
            .environmentObject(UsageManager()).frame(maxWidth: 440).padding(10)
    }
}
