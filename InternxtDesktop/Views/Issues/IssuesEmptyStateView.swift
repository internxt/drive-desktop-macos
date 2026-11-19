//
//  IssuesEmptyStateView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/8/26.
//

import SwiftUI

struct IssuesEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            AppIcon(iconName: .CheckCircle, size: 36, color: .Gray40)
            AppText("ISSUES_EMPTY_TITLE")
                .font(.SMMedium)
                .foregroundColor(.Gray100)
            AppText("ISSUES_EMPTY_SUBTITLE")
                .font(.XSRegular)
                .foregroundColor(.Gray60)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}


