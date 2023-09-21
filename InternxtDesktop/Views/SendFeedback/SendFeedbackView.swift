//
//  SendFeedbackView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import SwiftUI

struct SendFeedbackView: View {
    @State var feedback: String = ""
    @State var feedbackSent: Bool = false
    let charactersLimit = 1000
    var charactersCount = 0
    let closeWindow: () -> Void
    init(closeWindow: @escaping () -> Void) {
        self.closeWindow = closeWindow
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0){
            if feedbackSent {
                VStack(alignment: .center, spacing: 0){
                    AppIcon(iconName: .ChatCircle, size: 96, color: .Primary).padding(.bottom, 20)
                    AppText("SHARE_FEEDBACK_SUCCESS_TITLE")
                        .font(.LGMedium)
                        .frame(alignment:.center)
                    AppText("SHARE_FEEDBACK_SUCCESS_SUBTITLE")
                        .font(.BaseRegular).multilineTextAlignment(.center).padding(.bottom, 20)
                    AppButton(title: "COMMON_CLOSE", onClick: handleCloseWindow, type: .secondary, size: .MD)
                }
            } else {
                AppText("SHARE_FEEDBACK_TITLE")
                    .font(.LGMedium)
                    .padding(.bottom,4)
                AppText("SHARE_FEEDBACK_SUBTITLE")
                    .font(.BaseRegular)
                AppTextArea(placeholder: "SHARE_FEEDBACK_PLACEHOLDER", text: $feedback)
                    .padding(.top, 20)
                    .padding(.bottom, 8)
                HStack {
                    AppText("\(charactersCount)/\(charactersLimit)")
                        .font(.XSRegular)
                        .foregroundColor(.Gray80)
                    Spacer()
                    AppButton(title: "SHARE_FEEDBACK_ACTION", onClick: handleSendFeedback, size: .MD)
                }
            }
        }.padding(20).frame(width: 380, height: 320)
    }
    
    func handleSendFeedback() {
        Analytics.shared.track(key: .SEND_FEEDBACK, props: ["feedback": feedback])
        feedbackSent = true
    }
    
    func handleCloseWindow() {
        closeWindow()
    }
}

struct SendFeedbackView_Previews: PreviewProvider {
    static var previews: some View {
        SendFeedbackView(closeWindow: {})
    }
}
