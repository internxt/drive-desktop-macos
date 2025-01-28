//
//  CustomModalView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 21/1/25.
//

import SwiftUI

struct CustomModalView: View {
    let title: String
    let message: String
    let cancelTitle: String
    let confirmTitle: String
    let confirmColor: Color
    let onCancel: () -> Void
    let onConfirm: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            VStack(spacing: 8) {
                AppText(title)
                    .font(.LGMedium)
                    .foregroundColor(.Gray80)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding([.horizontal,.top])
                
                AppText(message)
                    .font(.BaseRegular)
                    .foregroundColor(.Gray60)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                HStack {
                    
                    AppButton(title: cancelTitle, onClick: {
                        withAnimation {
                            onCancel()
                        }
                    }, type: .secondary, size: .LG,isExpanded: true)
                    AppButton(title: confirmTitle, onClick: {
                        onConfirm()
                    }, type: confirmColor == .red ? .danger : .primary, size: .LG,isExpanded: true)
                    
                    
                }
                .padding([.leading, .trailing, .bottom])
                
            }
            .background(colorScheme == .dark ? Color.Gray1 : Color.white)
            .cornerRadius(12)
            .shadow(radius: 20)
            .frame(maxWidth: 320)
            .padding()
        }
    }
}
