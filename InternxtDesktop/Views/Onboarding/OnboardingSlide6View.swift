//
//  OnboardingSlide6View.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 30/1/25.
//

import SwiftUI

struct OnboardingSlide6View: View {
    public let goToNextSlide: () -> Void
    public let currentSlide: Int
    public let totalSlides: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_SLIDE_6_TITLE")
                .font(.XXXLSemibold)
                .foregroundColor(.Gray100)
                .padding(.bottom, 36)
            AppText("ONBOARDING_SLIDE_6_SUBTITLE")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 10)
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "COMMON_CONTINUE", onClick: goToNextSlide, size: .LG)
                Spacer()
                
                OnboardingSlideIndicator(currentSlide: currentSlide, totalSlides: totalSlides)
            }.transaction { transaction in
                transaction.animation = nil
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    OnboardingSlide6View(goToNextSlide: {}, currentSlide: 1, totalSlides: 1)
}
