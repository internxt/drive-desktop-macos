//
//  SendFeedbackView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import SwiftUI

struct SendFeedbackView: View {
    let charactersLimit = 1000
    var charactersCount = 0
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            AppText("SHARE_FEEDBACK_TITLE")
                .font(.LGMedium)
                .padding(.bottom,4)
            AppText("SHARE_FEEDBACK_SUBTITLE")
                .font(.BaseRegular)
            AppTextArea(placeholder: "SHARE_FEEDBACK_PLACEHOLDER")
                .padding(.top, 20)
                .padding(.bottom, 8)
            HStack {
                AppText("\(charactersCount)/\(charactersLimit)")
                    .font(.XSRegular)
                    .foregroundColor(.Gray80)
                Spacer()
                AppButton(title: "SHARE_FEEDBACK_ACTION", onClick: handleSendFeedback, size: .MD)
            }
        }.padding(20).frame(width: 380, height: 320)
    }
    
    func handleSendFeedback() {
        
    }
}

struct SendFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        SendFeedbackView()
    }
}
