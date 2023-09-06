//
//  AppAvatar.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/9/23.
//

import SwiftUI

struct AppAvatar: View {
    @Environment(\.colorScheme) var colorScheme
    public var avatarURL: String?
    public var name: String?
    public var size: CGFloat = 36
    var body: some View {
        HStack(alignment: .center){
            AppText(String(name?.first ?? "M"))
                .font(AppTextFont["Base/Semibold"])
                .foregroundColor(colorScheme == .dark ? Color.white : Color("Primary"))
                
        }
        .frame(width: size, height: size)
        .background(Color("Primary").opacity(colorScheme == .dark ? 0.75 : 0.2))
        .cornerRadius(999)
    }
}

struct AppAvatar_Previews: PreviewProvider {
    static var previews: some View {
        AppAvatar(name: "Test")
    }
}

