//
//  LockedFeatureCleanerView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/9/25.
//

import SwiftUI


struct LockedFeatureOverlay: View {
    var isVisible: Bool

    var body: some View {
        ZStack {
            Image("cleanerBlurIlustration")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .blur(radius: isVisible ? 3 : 0)
                .animation(.easeInOut(duration: 0.2), value: isVisible)
          
            if isVisible {
                Rectangle()
                    .fill(Color.black.opacity(0.4))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onTapGesture {
                    }
                
                LockedFeatureModal()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LockedFeatureModal: View {
      
    var body: some View {
        VStack(spacing: 15) {
            ZStack {

                Image("sparkleIcon")
                    .frame(width: 76, height: 76)
                
                Image("lockIcon")
                    .offset(x: 30, y: 39)
            }
            
            AppText("Locked feature")
                .font(.XXLSemibold)
                .foregroundColor(.Gray100)
            
            AppText("Please upgrade your plan to use this feature")
                .font(.SMRegular)
                .foregroundColor(.DefaultText)
                          
            AppButton(title: "COMMON_UPGRADE", onClick: {
                
                URLDictionary.UPGRADE_PLAN.open()
              
            })
        }
        .padding(32)
        .frame(width: 343)
        .frame(height: 282)
        .background(Color.DefaultBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
    }
}
