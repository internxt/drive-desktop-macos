//
//  SignInWithBrowserView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 16/8/23.
//

import SwiftUI

struct SignInWithBrowserView: View {
    @EnvironmentObject var authManager: AuthManager

    private var onLoginSuccess: () -> Void
    init(onLoginSuccess: @escaping () -> Void) {
        self.onLoginSuccess = onLoginSuccess
    }
    var body: some View {
        Color.Surface
        .ignoresSafeArea(.all)
        
        .overlay(
            VStack(alignment: .center, spacing: 0) {
                if authManager.isLoggedIn == false {
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
                    
                } else {
                    HStack {
                        AppText("You are now logged in, close this window")
                            .font(.LGMedium)
                            .foregroundColor(.Gray100)
                    }
                    
                    
                }
                
            }
            .frame(width: 300)
        ).onOpenURL(perform: {url in
            handleIncomingUrl(url)
        })
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
    
    func handleIncomingUrl(_ url: URL) {
        guard url.scheme == "internxt" else {
            print("Invalid scheme")
            return
        }
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Invalid URL")
            return
        }
        
        guard let action = components.host, action == "login-success" else {
            print("Unknown URL, not handling")
            return
        }
        
        guard let base64Mnemonic = components.queryItems?.first(where: { $0.name == "mnemonic" })?.value else {
            print("Mnemonic not found")
            return
        }
        
        
        guard let base64LegacyToken = components.queryItems?.first(where: { $0.name == "token" })?.value else {
            print("Legacy token not found")
            return
        }
        
        guard let base64Token = components.queryItems?.first(where: { $0.name == "newToken" })?.value else {
            print("Token not found")
            return
        }
        
        guard let decodedToken = Data(base64Encoded: base64Token.data(using: .utf8)!) else {
            print("Cannot decode token")
            return
        }
        
        guard let decodedLegacyToken = Data(base64Encoded: base64LegacyToken.data(using: .utf8)!) else {
            print("Cannot decode legacy token")
            return
        }
        
        guard let decodedMnemonic = Data(base64Encoded: base64Mnemonic.data(using: .utf8)!) else {
            print("Cannot decode mnemonic")
            return
        }
        
        do {
            try authManager.storeAuthDetails(
                plainMnemonic: String(data: decodedMnemonic, encoding: .utf8)!,
                authToken: String(data: decodedToken, encoding: .utf8)!,
                legacyAuthToken: String(data: decodedLegacyToken, encoding: .utf8)!
            )
            NSApplication.shared.keyWindow?.close()
            self.onLoginSuccess()
            
        } catch {
            print("Failed to login")
        }
        
       
    }
}

struct SignInWithBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        SignInWithBrowserView(onLoginSuccess: {}).environmentObject(AuthManager())
    }
}
