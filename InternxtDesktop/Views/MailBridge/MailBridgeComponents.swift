//
//  MailBridgeComponents.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI

enum MailBridgeMetrics {
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
    static let contentWidth: CGFloat = 590
}

extension Font {
    static let MailBridgeMono = Font.system(size: 12, design: .monospaced)
}

struct MailBridgeCard<Content: View>: View {
    var fill: Color = .Gray5
    var stroke: Color = .Gray10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: MailBridgeMetrics.cardRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: MailBridgeMetrics.cardRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }
}

struct MailBridgeDivider: View {
    var color: Color = .Gray10
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
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

struct MailBridgeClientChip: View {
    let client: MailClient
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Text(client.initial)
                    .font(.XSBold)
                    .foregroundColor(.Primary)
                    .frame(width: 24, height: 24)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.Secondary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Color.Gray10, lineWidth: 1)
                    )
                Text(client.displayName)
                    .font(.XSSemibold)
                    .foregroundColor(.Gray100)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
            .padding(9)
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
            MailBridgeDivider()
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

struct MailBridgePortField: View {
    let titleKey: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AppText(titleKey)
                .font(.XSMedium)
                .foregroundColor(.Gray50)
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(.MailBridgeMono)
                .foregroundColor(.Gray100)
                .padding(.horizontal, 10)
                .frame(width: 108, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: MailBridgeMetrics.controlRadius, style: .continuous)
                        .fill(Color.Secondary)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: MailBridgeMetrics.controlRadius, style: .continuous)
                        .strokeBorder(Color.Gray10, lineWidth: 1)
                )
                .onChange(of: text) { newValue in
                    let digits = newValue.filter(\.isNumber)
                    if digits != newValue { text = String(digits.prefix(5)) }
                }
        }
    }
}

struct MailBridgeGlyph: View {
    let systemName: String
    var tint: Color = .Gray50
    var size: CGFloat = 42

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.Secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.Gray10, lineWidth: 1)
            )
            .overlay(
                Image(systemName: systemName)
                    .font(.system(size: size * 0.4))
                    .foregroundColor(tint)
            )
            .frame(width: size, height: size)
    }
}
