//
//  CleanerTabView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 7/8/25.
//

import SwiftUI

enum CleanerViewState {
    case locked
    case scanning
    case results
}

struct CleanerTabView: View {
    @State private var viewState: CleanerViewState = .results
      
    var body: some View {
        ZStack {
            switch viewState {
            case .locked:
                LockedFeatureOverlay(isVisible: true)
            case .scanning:
                ScanningView()
            case .results:
                CleanupView()
            }
        }
    }
}

struct ScanningView: View {
    var body: some View {
        VStack {

        }
    }
}



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
    }
}



#Preview {
    CleanerTabView()
}
