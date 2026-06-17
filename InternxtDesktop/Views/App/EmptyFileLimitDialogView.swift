//
//  EmptyFileLimitDialogView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 15/6/26.
//

import SwiftUI

class EmptyFileLimitState: ObservableObject {
    @Published var isBatch: Bool = false
    @Published var firstFilename: String = ""
    @Published var rejectedCount: Int = 0
    @Published var reason: EmptyFileLimitReason = .quotaExceeded
    @Published var isVisible: Bool = false
}

struct EmptyFileLimitDialogView: View {
    @Environment(\.colorScheme) var colorScheme

    let isBatch: Bool
    let firstFilename: String
    let rejectedCount: Int
    let reason: EmptyFileLimitReason
    var onClose: () -> Void
    var onUpgrade: () -> Void

    private var titleText: String {
        switch reason {
        case .planNotAllowed:
            return NSLocalizedString(
                "empty_file_plan_title",
                value: "Empty files not available on your plan",
                comment: "Alert title when the user's plan does not allow empty files"
            )
        case .quotaExceeded:
            return NSLocalizedString(
                "empty_file_quota_title",
                value: "Empty file backup limit reached",
                comment: "Alert title when the empty-file quota is full"
            )
        }
    }

    private var messageText: String {
        switch reason {
        case .planNotAllowed:
            if isBatch {
                return String(
                    format: NSLocalizedString(
                        "empty_file_plan_batch_message",
                        value: "%d empty files could not be backed up. Upgrade your plan to back up empty files.",
                        comment: "Alert body when multiple empty files are rejected due to plan restriction"
                    ),
                    rejectedCount
                )
            } else {
                return String(
                    format: NSLocalizedString(
                        "empty_file_plan_single_message",
                        value: "'%@' could not be backed up. Upgrade your plan to back up empty files.",
                        comment: "Alert body when a single empty file is rejected due to plan restriction"
                    ),
                    firstFilename
                )
            }
        case .quotaExceeded:
            if isBatch {
                return String(
                    format: NSLocalizedString(
                        "empty_file_quota_batch_message",
                        value: "%d empty files could not be backed up because your account has reached the empty file limit.",
                        comment: "Alert body when multiple empty files are rejected due to quota"
                    ),
                    rejectedCount
                )
            } else {
                return String(
                    format: NSLocalizedString(
                        "empty_file_quota_single_message",
                        value: "'%@' could not be backed up because your account has reached the empty file limit.",
                        comment: "Alert body when a single empty file is rejected due to quota"
                    ),
                    firstFilename
                )
            }
        }
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
                if reason == .quotaExceeded {
                    AppButton(
                        title: "Close",
                        onClick: { onClose() },
                        type: .primary,
                        size: .MD
                    )
                } else {
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
        }
        .padding(24)
        .frame(width: 420, height: 200)
    }
}

struct EmptyFileLimitWindowView: View {
    @EnvironmentObject var state: EmptyFileLimitState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.Gray1 : Color.white)
                .ignoresSafeArea()

            EmptyFileLimitDialogView(
                isBatch:        state.isBatch,
                firstFilename:  state.firstFilename,
                rejectedCount:  state.rejectedCount,
                reason:         state.reason,
                onClose: {
                    state.isVisible = false
                    NSApp.hide(nil)
                },
                onUpgrade: {
                    URLDictionary.UPGRADE_PLAN_DEEP_LINK.open()
                    state.isVisible = false
                    NSApp.hide(nil)
                }
            )
        }
    }
}
