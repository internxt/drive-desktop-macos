//
//  OnboardingFinishView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 14/9/23.
//

import SwiftUI

struct OnboardingFinishView: View {
    public let finishOnboarding: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("ONBOARDING_FINISH_TITLE")
                .font(.XXXLSemibold)
                .padding(.bottom, 36)
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle().foregroundColor(.Primary).frame(height: 20 )
                    AppIcon(iconName: .Check, size: 12, color: Color.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    AppText("ONBOARDING_FINISH_SUBTITLE_1")
                        .font(.LGMedium)
                        .foregroundColor(.Gray100)
                        .padding(.bottom, 2)
                        
                    AppText("ONBOARDING_FINISH_SUBTITLE_2")
                        .font(.BaseRegular)
                        .foregroundColor(.Gray50)
                }
            }
            
            
            
                
            Spacer()
            HStack(spacing: 8) {
                AppButton(title: "ONBOARDING_FINISH_ACTION", onClick: finishOnboarding, size: .LG)
                Spacer()
            }
        }.frame(minWidth: 0, maxWidth: .infinity,minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct OnboardingFinishView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingFinishView(finishOnboarding: {})
    }
}
