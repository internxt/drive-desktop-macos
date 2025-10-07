//
//  OnboardingView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 13/9/23.
//

import SwiftUI

struct OnboardingView: View {
    public let finishOrSkipOnboarding: () -> Void
    public let totalSlides = 4
    @State var currentSlideIndex = 0
    var body: some View {
        HStack(alignment: .top,spacing: 0){
            VStack(alignment: .leading,spacing:0) {
                CurrentSlideView.transition(.onboardingText)
            }
            .padding(.top, 64)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
            .frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity)
            .background(Color.Gray1)
            
            Divider()
                .frame(maxWidth: 1, maxHeight: .infinity)
                .overlay(Color.Gray10)
                .zIndex(5)
            HStack(alignment: .top) {
                CurrentSlideImage
                    .transition(.onboardingImage)
            }
            .frame(maxWidth: 400, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.Gray5)
        }
        
    }
    
    @ViewBuilder
    var CurrentSlideView: some View {
        switch currentSlideIndex{
        case 0:
            WelcomeSlideView(
                goToNextSlide: handleGoToNextSlide,
                skipOnboarding: handleSkipOnboarding
            )
        case 1:
            OnboardingSlide4View(
                goToNextSlide: handleGoToNextSlide,
                currentSlide: currentSlideIndex + 1,
                totalSlides: totalSlides
            )
        case 2:
            OnboardingSlide7View(
                goToNextSlide: handleGoToNextSlide,
                currentSlide: currentSlideIndex + 1,
                totalSlides: totalSlides
            )
        case 3:
            OnboardingSlide6View(
                goToNextSlide: handleGoToNextSlide,
                currentSlide: currentSlideIndex + 1,
                totalSlides: totalSlides
            )
        case 4:
            OnboardingSlide3View(
                goToNextSlide: handleGoToNextSlide,
                currentSlide: currentSlideIndex + 1,
                totalSlides: totalSlides
            )
        case 5:
            OnboardingFinishView(finishOnboarding: handleFinishOnboarding)

        default:
            EmptyView()
        }
    }
    
    @ViewBuilder
    var CurrentSlideImage: some View {
        switch currentSlideIndex{
        case 0, 5:
            ZStack(alignment: .top) {
                Image("FinderIllustration")
            }.offset(x: 80, y: 80)
        case 1:
            ZStack(alignment: .top) {
                Image("AvailableOnlineIllustration")
            }.offset(x: 80, y: 80)
        case 2:
            VStack(alignment: .center) {
                Image("folderIllustration").resizable()
                    .scaledToFit().frame(width: 252,height: 264)

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case 3:
            VStack(alignment: .center) {
                Image("virusIllustration").resizable()
                    .scaledToFit().frame(width: 204)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        
        case 4:
            VStack(alignment: .center) {
                Image("cleanerOnboardingIllustration").resizable()
                    .scaledToFit().frame(width: 204)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case 6:
            VStack(alignment: .center) {
                Image("folderIllustration").resizable()
                    .scaledToFit().frame(width: 204)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        default:
            EmptyView()
        }
    }
    
    
    func handleSkipOnboarding() {
        finishOrSkipOnboarding()
    }
    
    func handleFinishOnboarding() {
        finishOrSkipOnboarding()
    }
    
    func handleGoToNextSlide() {
        withAnimation(.easeIn(duration: 0.35).delay(0.5)) {
            currentSlideIndex = currentSlideIndex + 1
        }
        
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView(finishOrSkipOnboarding: {}).frame(width: 800, height: 470)
    }
}
