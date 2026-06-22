//
//  StorageFullDialogView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 17/6/26.
//

import SwiftUI

class StorageFullState: ObservableObject {
    @Published var isVisible: Bool = false
}

struct StorageFullDialogView: View {
    @Environment(\.colorScheme) var colorScheme

    var onClose: () -> Void
    var onUpgrade: () -> Void

    private var titleText: String {
        return NSLocalizedString(
            "storage_full_title",
            value: "Your storage is full",
            comment: "Alert title when the user runs out of storage space"
        )
    }

    private var messageText: String {
        return NSLocalizedString(
            "storage_full_message",
            value: "You have run out of space on Internxt. Upgrade your plan to continue backing up your files.",
            comment: "Alert body when storage is full"
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titleText)
                .font(.XLMedium)
                .foregroundColor(.DefaultTextStrong)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 12)

            Text(messageText)
                .font(.SMRegular)
                .foregroundColor(.Gray60)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 24)

            Spacer()

            HStack(spacing: 8) {
                Spacer()
                AppButton(
                    title: "Close",
                    onClick: { onClose() },
                    type: .secondary,
                    size: .MD
                )
                AppButton(
                    title: "Upgrade plan",
                    onClick: { onUpgrade() },
                    type: .primary,
                    size: .MD
                )
            }
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}

struct StorageFullWindowView: View {
    @EnvironmentObject var state: StorageFullState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.Gray1 : Color.white)
                .ignoresSafeArea()

            StorageFullDialogView(
                onClose: {
                    state.isVisible = false
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "storage-full" }) {
                        window.close()
                    }
                },
                onUpgrade: {
                    URLDictionary.UPGRADE_PLAN_DEEP_LINK.open()
                    state.isVisible = false
                    if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "storage-full" }) {
                        window.close()
                    }
                }
            )
        }
    }
}
