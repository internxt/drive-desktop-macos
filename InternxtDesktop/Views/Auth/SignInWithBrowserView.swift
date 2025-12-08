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
                            .accessibilityIdentifier("buttonDontHaveAccount")

                        AppText("AUTH_CREATE_ACCOUNT")
                            .font(.BaseMedium)
                            .foregroundColor(.Primary)
                            .onTapGesture {self.openSignUpUrl()}
                            .accessibilityIdentifier("buttonCreateAccountLogin")
                        
                        
                    }.padding(.top, 24)
                }
                    .frame(width: 300)
            )
    }
    
    func openSignUpUrl() {
        URLDictionary.WEB_AUTH_SIGNUP.open()
    }
    
    func openSignInUrl() {
        URLDictionary.WEB_AUTH_SIGNIN.open()
    }
}

struct SignInWithBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithBrowserView().environmentObject(AuthManager())
    }
}
