//
//  OnboardingSlide2View.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 13/9/23.
//

import SwiftUI

struct OnboardingSlide2View: View {
    public let goToNextSlide: () -> Void
    public let currentSlide: Int
    public let totalSlides: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_SLIDE_2_TITLE")
                .font(.XXXLSemibold)
                .foregroundColor(.Gray100)
                .padding(.bottom, 36)
            AppText("ONBOARDING_SLIDE_2_SUBTITLE")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 10)
            
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "COMMON_CONTINUE", onClick: goToNextSlide, size: .LG)
                Spacer()
                
                OnboardingSlideIndicator(currentSlide: currentSlide, totalSlides: totalSlides)
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OnboardingSlide2View_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlide2View(goToNextSlide: {}, currentSlide: 1, totalSlides: 1)
    }
}
