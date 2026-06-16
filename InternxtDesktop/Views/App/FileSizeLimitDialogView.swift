//
//  FileSizeLimitDialogView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 12/5/26.
//

import Foundation
import SwiftUI


class FileSizeLimitState: ObservableObject {
    @Published var isBatch:    Bool   = false
    @Published var filename:   String = ""
    @Published var fileSize:   Int64  = 0
    @Published var limitBytes: Int64  = 0
    @Published var isVisible:  Bool   = false
}


struct FileSizeLimitDialogView: View {

    @Environment(\.colorScheme) var colorScheme

    let isBatch:      Bool
    let filename:     String
    let fileSize:     Int64
    let limitBytes:   Int64
    var onClose:      () -> Void
    var onUpgrade:    () -> Void

  

    private var isOver100GB: Bool {
        fileSize > 100 * 1024 * 1024 * 1024
    }

    private var limitMB: String {
        formatBytes(limitBytes)
    }

    private var fileSizeMB: String {
        formatBytes(fileSize)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.0f GB", mb / 1024)
        }
        return String(format: mb >= 10 ? "%.0f MB" : "%.1f MB", mb)
    }

    private var planTiers: [(name: String, limit: String, highlighted: Bool)] {
        let essentialLimit: Int64 = 10 * 1024 * 1024 * 1024
        let premiumLimit:   Int64 = 50 * 1024 * 1024 * 1024
        let ultimateLimit:  Int64 = 100 * 1024 * 1024 * 1024

        let highlightEssential = fileSize <= essentialLimit
        let highlightPremium   = fileSize > essentialLimit && fileSize <= premiumLimit
        let highlightUltimate  = fileSize > premiumLimit && fileSize <= ultimateLimit

        return [
            ("Essential", "10 GB",  highlightEssential),
            ("Premium",   "50 GB",  highlightPremium),
            ("Ultimate",  "100 GB", highlightUltimate),
        ]
    }

  

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

          
            Group {
                if isOver100GB {
                    if isBatch {
                        Text("Some files exceed the size limit")
                    } else {
                        Text("File size exceeds limit")
                    }
                } else if isBatch {
                    Text("Some files are too large for your current plan")
                } else {
                    Text("This file is too large for your current plan")
                }
            }
            .font(.XLMedium)
            .foregroundColor(.DefaultTextStrong)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)


            Group {
                if isOver100GB {
                    if isBatch {
                        Text("The maximum file size allowed is 100 GB. Some of your files exceed this limit and cannot be uploaded.")
                    } else {
                        Text("The maximum file size allowed is 100 GB. This file is \(fileSizeMB) and cannot be uploaded.")
                    }
                } else if isBatch {
                    Text("Your plan allows uploads up to \(limitMB). Upgrade your plan to upload larger files.")
                } else {
                    Text("Your plan allows uploads up to \(limitMB). This file is \(fileSizeMB). Upgrade your plan to upload larger files.")
                }
            }
            .font(.SMRegular)
            .foregroundColor(.Gray60)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)

     
            if isOver100GB {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 20))
                    Text("Files larger than 100 GB cannot be uploaded to Internxt due to infrastructure limits.")
                        .font(.SMRegular)
                        .foregroundColor(.Gray80)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(nil)
                }
                .padding(12)
                .background(Color.red.opacity(colorScheme == .dark ? 0.15 : 0.08))
                .cornerRadius(8)
                .padding(.bottom, 24)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(planTiers, id: \.name) { tier in
                        HStack(alignment: .center, spacing: 8) {
                        
                            Circle()
                                .fill(tier.highlighted ? Color.DefaultTextStrong : Color.Gray40)
                                .frame(width: 5, height: 5)

                     
                            HStack(spacing: 0) {
                                Text(tier.name)
                                    .font(tier.highlighted ? .SMBold : .SMRegular)
                                    .foregroundColor(tier.highlighted ? .DefaultTextStrong : .Gray80)
                                Text(" → up to \(tier.limit)")
                                    .font(tier.highlighted ? .SMBold : .SMRegular)
                                    .foregroundColor(tier.highlighted ? .DefaultTextStrong : .Gray80)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }

            Spacer()

            HStack(spacing: 8) {
                Spacer()
                if isOver100GB {
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
        .frame(width: 420, height: 270)
    }
}



struct FileSizeLimitWindowView: View {
    @EnvironmentObject var state: FileSizeLimitState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
         
            (colorScheme == .dark ? Color.Gray1 : Color.white)
                .ignoresSafeArea()

            FileSizeLimitDialogView(
                isBatch:    state.isBatch,
                filename:   state.filename,
                fileSize:   state.fileSize,
                limitBytes: state.limitBytes,
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
