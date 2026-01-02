//
//  AppTextArea.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import SwiftUI

struct AppTextArea: View {
    var placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                AppText(placeholder)
                    .font(.BaseRegular)
                    .foregroundColor(.Gray30)
                    .zIndex(10)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
            }
            TextEditor(text: $text)
                .font(.BaseRegular)
                .foregroundColor(.Gray100)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.Gray40, lineWidth: 1)
                        .zIndex(5)
                }
        }
    }
}

struct AppTextArea_Previews: PreviewProvider {
    static var previews: some View {
        AppTextArea(placeholder: "Your input goes here", text: .constant("")).frame(width: 300, height: 300).padding(16)
    }
}
