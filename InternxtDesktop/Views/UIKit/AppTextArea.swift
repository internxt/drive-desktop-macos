//
//  AppTextArea.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import SwiftUI

struct AppTextArea: View {
    var placeholder: String
    @State var text: String = ""
    
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                AppText(placeholder)
                    .font(.BaseRegular)
                    .foregroundColor(.Gray30)
                    .zIndex(10)
            }
            TextEditor(text: $text)
                .font(.BaseRegular)
                .foregroundColor(.Gray100)
                .frame(maxWidth: .infinity)
                .ifAvailable {
                    if #available(macOS 13.0, *) {
                        $0.scrollContentBackground(.hidden).scrollContentBackground(.hidden)
                    }
                }
                .ifAvailable {
                    if #available(macOS 13.0, *) {
                        $0.scrollContentBackground(.hidden)
                    }
                }
                
        }
        
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .overlay{
            RoundedRectangle(cornerRadius: 8)
                .stroke(isFocused ? Color.Primary : Color.Gray40, lineWidth: 1)
                .zIndex(5)
        }
        
    }
}

struct AppTextArea_Previews: PreviewProvider {
    static var previews: some View {
        AppTextArea(placeholder: "Your input goes here").frame(width: 300, height: 300).padding(16)
    }
}
