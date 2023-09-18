//
//  AnyTransition.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 18/9/23.
//

import Foundation
import SwiftUI

extension AnyTransition {
    static var onboardingText: AnyTransition {
        return .asymmetric(
            insertion: .opacity.animation(.easeOut(duration: 0.35).delay(0.35)),
            removal: .opacity.animation(.easeIn(duration: 0.35))
        )
    }
    
    static var onboardingImage: AnyTransition {
        return .asymmetric(
            insertion: .offset(x: 0, y: 32).combined(with: .opacity),
            removal: .opacity.animation(.easeIn(duration: 0.35))
        )
    }
}
