//
//  WelcomeSlideView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 13/9/23.
//

import SwiftUI

struct WelcomeSlideView: View {
    public let goToNextSlide: () -> Void
    public let skipOnboarding: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_SLIDE_1_TITLE")
                .font(.XXXLSemibold)
                .foregroundColor(.Gray100)
                .padding(.bottom, 36)
            AppText("ONBOARDING_SLIDE_1_SUBTITLE_1")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 10)
            AppText("ONBOARDING_SLIDE_1_SUBTITLE_2")
                .foregroundColor(.Gray100)
                .font(.LGRegular)
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "ONBOARDING_SLIDE_1_ACTION", onClick: goToNextSlide, size: .LG)
                AppButton(title: "COMMON_SKIP", onClick: skipOnboarding, type: .secondaryWhite,size: .LG)
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct WelcomeSlideView_Previews: PreviewProvider {
    static var previews: some View {
        WelcomeSlideView(goToNextSlide: {}, skipOnboarding: {})
    }
}
