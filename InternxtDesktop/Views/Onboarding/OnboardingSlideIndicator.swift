//
//  OnboardingSlideIndicator.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 13/9/23.
//

import SwiftUI

struct OnboardingSlideIndicator: View {
    public let currentSlide: Int
    public let totalSlides: Int
    var body: some View {
        Text("PAGE_INDICATOR_\(currentSlide - 1)_OF_\(totalSlides)")
            .font(.BaseRegular)
            .foregroundColor(.Gray50)
    }
}

struct OnboardingSlideIndicator_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingSlideIndicator(currentSlide: 1, totalSlides: 5)
    }
}
