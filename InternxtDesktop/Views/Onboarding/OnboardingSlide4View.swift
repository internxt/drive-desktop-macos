//
//  OnboardingSlide4View.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import SwiftUI

struct OnboardingSlide4View: View {
    public let goToNextSlide: () -> Void
    public let currentSlide: Int
    public let totalSlides: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_SLIDE_4_TITLE")
                .font(.XXXLSemibold)
                .foregroundColor(.Gray100)
                .padding(.bottom, 36)
            AppText("ONBOARDING_SLIDE_4_SUBTITLE_1")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 10)
            AppText("ONBOARDING_SLIDE_4_SUBTITLE_2")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "COMMON_CONTINUE", onClick: goToNextSlide, size: .LG)
                Spacer()
                
                OnboardingSlideIndicator(currentSlide: currentSlide, totalSlides: totalSlides)
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OnboardingSlide4View_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlide4View(goToNextSlide: {}, currentSlide: 3, totalSlides: 5)
    }
}
