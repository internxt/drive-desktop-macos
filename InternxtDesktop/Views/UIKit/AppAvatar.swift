//
//  AppAvatar.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 5/9/23.
//

import SwiftUI

struct AppAvatar: View {
    @Environment(\.colorScheme) var colorScheme
   
    public var name: String?
    public var size: CGFloat = 36
    public var font = Font.BaseSemibold
    public var avatarURL: String?
    var body: some View {
        HStack(alignment: .center){
            if let urlUnwrapped = avatarURL {
                AppCachedAsyncImage(url: URL(string: urlUnwrapped)){ phase in
                    switch phase {
                    case .empty:
                        ProgressView().controlSize(.small)
                    case .success(let image):
                        image.resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: size, maxHeight: size)
                        
                            
                    case .failure:
                        AppText(String(name?.first ?? "M"))
                            .font(font)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color("Primary"))
                    @unknown default:
                        EmptyView()
                    }
                }

            } else {
                AppText(String(name?.first ?? "M"))
                    .font(font)
                    .foregroundColor(colorScheme == .dark ? Color.white : Color("Primary"))
            }
            
                
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

