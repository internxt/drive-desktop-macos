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

    private let planTiers: [(name: String, limit: String, highlighted: Bool)] = [
        ("Essential", "10 GB",  false),
        ("Premium",   "50 GB",  true),
        ("Ultimate",  "100 GB", false),
    ]

  

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

          
            Group {
                if isBatch {
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
                if isBatch {
                    Text("Your plan allows uploads up to \(limitMB). Upgrade your plan to upload larger files.")
                } else {
                    Text("Your plan allows uploads up to \(limitMB). This file is \(fileSizeMB). Upgrade your plan to upload larger files.")
                }
            }
            .font(.SMRegular)
            .foregroundColor(.Gray60)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.bottom, 12)

     
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
        .background(colorScheme == .dark ? Color.Gray1 : Color.white)
        .cornerRadius(12)
        .frame(width: 370)
        .frame(height: 220)
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
        .shadow(color: .black.opacity(0.04), radius:  2, x: 0, y: 1)
    }
}



struct FileSizeLimitWindowView: View {
    @EnvironmentObject var state: FileSizeLimitState
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        ZStack {
         
            (colorScheme == .dark ? Color.Gray1 : Color.Surface)
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
                    URL(string: "https://internxt.com/pricing")?.open()
                    state.isVisible = false
                    NSApp.hide(nil)
                }
            )
            .padding(24)
        }
    }
}
