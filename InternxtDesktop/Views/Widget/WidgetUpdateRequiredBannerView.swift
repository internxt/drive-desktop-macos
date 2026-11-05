//
//  WidgetUpdateRequiredBannerView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 3/11/26.
//

import SwiftUI

public struct WidgetUpdateRequiredBannerView: View {
    public var onUpdate: () -> Void

    public init(onUpdate: @escaping () -> Void = {}) {
        self.onUpdate = onUpdate
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .foregroundColor(.Orange)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    AppText("WIDGET_UPDATE_REQUIRED_TITLE")
                        .font(.XSSemibold)
                        .foregroundColor(.DefaultTextStrong)

                    AppText("WIDGET_UPDATE_REQUIRED_BODY")
                        .font(.XSRegular)
                        .foregroundColor(.Gray60)
                        .fixedSize(horizontal: false, vertical: true)
                }

                AppButton(
                    title: "UPDATE_REQUIRED_BUTTON",
                    onClick: {
                        onUpdate()
                    },
                    type: .primary,
                    size: .SM
                )
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.Gray1)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0.0, y: 1.0)
        .padding([.horizontal, .top], 12)
    }
}

#Preview {
    WidgetUpdateRequiredBannerView()
}
