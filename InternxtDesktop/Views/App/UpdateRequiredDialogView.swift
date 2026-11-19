//
//  UpdateRequiredDialogView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 3/11/26.
//

import SwiftUI

public class UpdateRequiredState: ObservableObject {
    @Published public var isVisible: Bool = false

    public init() {}
}

public struct UpdateRequiredDialogView: View {
    @Environment(\.colorScheme) var colorScheme

    public var onUpdate: () -> Void

    public init(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AppText("UPDATE_REQUIRED_TITLE")
                .font(.XLMedium)
                .foregroundColor(.DefaultTextStrong)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            AppText("UPDATE_REQUIRED_MESSAGE")
                .font(.SMRegular)
                .foregroundColor(.Gray60)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            Spacer()

            HStack(spacing: 8) {
                Spacer()
                AppButton(
                    title: "UPDATE_REQUIRED_BUTTON",
                    onClick: { onUpdate() },
                    type: .primary,
                    size: .MD
                )
            }
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}

public struct UpdateRequiredWindowView: View {
    @EnvironmentObject var state: UpdateRequiredState
    @Environment(\.colorScheme) var colorScheme
    public var onUpdate: () -> Void

    public init(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
    }

    public var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.Gray1 : Color.white)
                .ignoresSafeArea()

            UpdateRequiredDialogView(
                onUpdate: {
                    onUpdate()
                }
            )
        }
    }
}
