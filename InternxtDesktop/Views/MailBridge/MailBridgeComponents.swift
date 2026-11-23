//
//  MailBridgeComponents.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI
import AppKit

enum MailBridgeMetrics {
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let contentWidth: CGFloat = 590
}

extension Font {
    static let MailBridgeMono = Font.system(size: 12, design: .monospaced)
}

struct MailBridgeProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.Gray10)
                Capsule().fill(Color.Primary)
                    .frame(width: max(0, min(1, value)) * geo.size.width)
            }
        }
        .frame(height: 4)
    }
}

struct MailBridgeCredentialRow: View {
    let row: CredentialRow
    let isRevealed: Bool
    let isCopied: Bool
    let onCopy: () -> Void

    private var isHidden: Bool { row.isSecret && !isRevealed }

    var body: some View {
        VStack(spacing: 0) {
            AppDivider()
            HStack(spacing: 8) {
                AppText(isCopied ? "MAIL_BRIDGE_COPIED" : row.labelKey)
                    .font(.XSMedium)
                    .foregroundColor(isCopied ? .GreenDark : .Gray50)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(width: 76, alignment: .leading)

                Text(row.value)
                    .font(.MailBridgeMono)
                    .foregroundColor(.Gray100)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .blur(radius: isHidden ? 3.5 : 0)
                    .animation(.easeOut(duration: 0.15), value: isHidden)
                    .accessibilityValue(isHidden ? Text("MAIL_BRIDGE_HIDDEN_VALUE") : Text(row.value))

                Spacer(minLength: 0)

                Button(action: onCopy) {
                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundColor(isCopied ? .GreenDark : .Gray50)
                        .frame(width: 24, height: 24)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("MAIL_BRIDGE_COPY_HELP")
            }
            .padding(.vertical, 5)
        }
    }
}

struct MailBridgeClientChip: View {
    private static let iconSize: CGFloat = 18

    let client: MailClient
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 7) {
                icon
                Text(client.displayName)
                    .font(.XSSemibold)
                    .foregroundColor(.Gray100)
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.PrimaryBadge : Color.Gray5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isSelected ? Color.Primary : Color.Gray10, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
    }

    @ViewBuilder
    private var icon: some View {
        if let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: client.bundleIdentifier) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: application.path))
                .resizable()
                .frame(width: Self.iconSize, height: Self.iconSize)
        } else {
            Text(client.initial)
                .font(.XSBold)
                .foregroundColor(.Primary)
                .frame(width: Self.iconSize, height: Self.iconSize)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous).fill(Color.Secondary)
                )
        }
    }
}
