//
//  OnboardingSlide3View.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import SwiftUI

struct OnboardingSlide3View: View {
    public let goToNextSlide: () -> Void
    public let currentSlide: Int
    public let totalSlides: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                AppText("ONBOARDING_SLIDE_3_TITLE")
                    .font(.XXXLSemibold)
                    .foregroundColor(.Gray100)
                
                AppText("New")
                    .font(.XSSemibold)
                    .foregroundColor(Color.Primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.PrimaryBadge)
                    )
                    .offset(y: -2)
                
                Spacer()
            }
            .padding(.bottom, 36)
            
            AppText("ONBOARDING_SLIDE_3_SUBTITLE_1")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 10)
            
            AppText("ONBOARDING_SLIDE_3_SUBTITLE_2")
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
        }.frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OnboardingSlide3View_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlide3View(goToNextSlide: {}, currentSlide: 3, totalSlides: 5)
    }
}
