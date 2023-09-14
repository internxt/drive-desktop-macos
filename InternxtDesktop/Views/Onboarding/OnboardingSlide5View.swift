//
//  OnboardingSlide5View.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import SwiftUI

struct OnboardingSlide5View: View {
    public let goToNextSlide: () -> Void
    public let currentSlide: Int
    public let totalSlides: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_SLIDE_5_TITLE")
                .font(.XXXLSemibold)
                .foregroundColor(.Gray100)
                .padding(.bottom, 36)
            AppText("ONBOARDING_SLIDE_5_SUBTITLE_1")
                .font(.LGRegular)
                .foregroundColor(.Gray100)
                .padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 16) {
                BulletListItem(text: "ONBOARDING_SLIDE_5_LIST_ITEM_1")
                BulletListItem(text: "ONBOARDING_SLIDE_5_LIST_ITEM_2")
            }
            
                
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "COMMON_CONTINUE", onClick: goToNextSlide, size: .LG)
                Spacer()
                
                OnboardingSlideIndicator(currentSlide: currentSlide, totalSlides: totalSlides)
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
    
    
    func BulletListItem(text: String) -> some View {
        return HStack(alignment: .top, spacing: 10){
            AppText("\u{2022}")
                .font(.LGSemibold)
                .foregroundColor(.Gray100)
            AppText(text)
                .font(.LGRegular)
                .foregroundColor(.Gray100)
        }
    }
}

struct OnboardingSlide5View_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlide5View(goToNextSlide: {}, currentSlide: 4, totalSlides: 5)
    }
}
