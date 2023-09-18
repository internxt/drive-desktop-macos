//
//  SignInWithBrowserView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 16/8/23.
//

import SwiftUI

struct SignInWithBrowserView: View {

 
    var body: some View {
        Color.Surface
        .ignoresSafeArea(.all)
        
        .overlay(
            VStack(alignment: .center, spacing: 0) {
                AppText("AUTH_WELCOME_TITLE")
                    .font(.XXLMedium)
                    .foregroundColor(.Highlight)
                    .padding(.bottom,12)
                AppButton(title: "AUTH_USE_BROWSER", onClick: openSignInUrl, size: .LG)
                    .padding(.bottom, 24)
                Divider()
                    .frame(maxWidth: .infinity, maxHeight: 1).overlay(Color.Gray10)
                HStack{
                    AppText("AUTH_DONT_HAVE_ACCOUNT")
                        .font(.BaseMedium)
                        .foregroundColor(.Gray60)
                    
                    AppText("AUTH_CREATE_ACCOUNT")
                        .font(.BaseMedium)
                        .foregroundColor(.Primary)
                        .onTapGesture {self.openSignUpUrl()}
                    
                    
                }.padding(.top, 24)
            }
            .frame(width: 300)
        )
    }
    
    func openSignUpUrl() {
        if let url = URL(string: URLDictionary.WEB_AUTH_SIGNUP) {
               NSWorkspace.shared.open(url)
        }
    }
    
    func openSignInUrl() {
        if let url = URL(string: URLDictionary.WEB_AUTH_SIGNIN) {
               NSWorkspace.shared.open(url)
        }
    }
}

struct SignInWithBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithBrowserView().environmentObject(AuthManager())
    }
}
