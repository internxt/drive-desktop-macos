//
//  MailBridgeActiveView.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 09/09/2026.
//

import SwiftUI
import AppKit

struct MailBridgeActiveView: View {
    @ObservedObject var service: MailBridgeService
    let onOpenSettings: () -> Void

    @State private var selectedClient: MailClient = .appleMail
    @State private var manualSettingsExpanded: Bool = true
    @State private var revealPassword: Bool = false
    @State private var copiedRowID: String?
    @State private var copiedAll: Bool = false

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
                statusCard
                clientHeader
                clientPicker
                actionRow

                if manualSettingsExpanded {
                    manualSettings.padding(.top, 16)
                }

                Text(service.autostartNote)
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 18)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var setupAutomaticallyTitle: String {
        String(
            format: NSLocalizedString("MAIL_BRIDGE_SETUP_AUTOMATICALLY_%@", comment: "Configure the selected mail client"),
            selectedClient.displayName
        )
    }

    // MARK: - Clipboard

    private func copy(_ row: CredentialRow) {
        setClipboard(row.value)
        copiedRowID = row.id
        Task {
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            if copiedRowID == row.id { copiedRowID = nil }
        }
    }

    private func copyAll() {
        setClipboard(service.credentials.clipboardSummary())
        copiedAll = true
        Task {
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            copiedAll = false
        }
    }

    private func setClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }

    // MARK: - Status

    private var statusCard: some View {
        MailBridgeCard(fill: .PrimaryBadge, stroke: Color.Primary.opacity(0.3)) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.GreenDark)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(Color.GreenDark.opacity(0.18), lineWidth: 3))

                    AppText("MAIL_BRIDGE_RUNNING")
                        .font(.SMSemibold)
                        .foregroundColor(.Gray100)

                    Spacer(minLength: 8)

                    Button(action: { service.resync() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                            AppText("MAIL_BRIDGE_RESYNC")
                        }
                    }
                    .buttonStyle(SecondaryAppButtonStyle(size: .SM, isEnabled: true, isExpanded: false))

                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(SecondaryAppButtonStyle(size: .SM, isEnabled: true, isExpanded: false))
                    .help("MAIL_BRIDGE_SETTINGS_TITLE")

                    AppButton(
                        title: "MAIL_BRIDGE_TURN_OFF",
                        onClick: { service.deactivate() },
                        type: .secondary,
                        size: .SM
                    )
                }

                Text(service.endpointSummary)
                    .font(.MailBridgeMono)
                    .foregroundColor(.Gray60)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.top, 6)

                MailBridgeDivider(color: Color.Primary.opacity(0.3))
                    .padding(.top, 13)

                HStack(alignment: .bottom, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(service.progressSummary)
                            .font(.XSRegular)
                            .foregroundColor(.Gray60)
                        MailBridgeProgressBar(value: service.progress)
                    }
                    Text(service.estimatedRemaining)
                        .font(.XSRegular)
                        .foregroundColor(.Gray50)
                        .fixedSize()
                }
                .padding(.top, 12)
            }
            .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
        }
    }

    // MARK: - Mail client

    private var clientHeader: some View {
        VStack(alignment: .leading, spacing: 3) {
            AppText("MAIL_BRIDGE_CONNECT_CLIENT_TITLE")
                .font(.SMSemibold)
                .foregroundColor(.Gray100)
            AppText("MAIL_BRIDGE_CONNECT_CLIENT_SUBTITLE")
                .font(.XSRegular)
                .foregroundColor(.Gray50)
        }
        .padding(.top, 20)
    }

    private var clientPicker: some View {
        HStack(spacing: 8) {
            ForEach(MailClient.allCases) { client in
                MailBridgeClientChip(
                    client: client,
                    isSelected: selectedClient == client,
                    onSelect: { selectedClient = client }
                )
            }
        }
        .padding(.top, 12)
    }

    private var actionRow: some View {
        HStack(spacing: 14) {
            Button(action: { service.configureAutomatically(selectedClient) }) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill").font(.system(size: 12))
                    Text(setupAutomaticallyTitle)
                }
            }
            .buttonStyle(PrimaryAppButtonStyle(size: .MD, isEnabled: true, isExpanded: false))

            Button {
                withAnimation(.easeOut(duration: 0.16)) { manualSettingsExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .rotationEffect(.degrees(manualSettingsExpanded ? 0 : -90))
                    AppText(manualSettingsExpanded ? "MAIL_BRIDGE_HIDE_MANUAL" : "MAIL_BRIDGE_SHOW_MANUAL")
                }
                .font(.XSSemibold)
                .foregroundColor(.Primary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
    }

    // MARK: - Manual settings

    private var manualSettings: some View {
        MailBridgeCard {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    AppText("MAIL_BRIDGE_MANUAL_SETTINGS")
                        .font(.XSSemibold)
                        .foregroundColor(.Gray100)

                    AppText("MAIL_BRIDGE_LOCAL_ONLY")
                        .font(.XXSSemibold)
                        .kerning(0.5)
                        .foregroundColor(.Primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.PrimaryBadge))

                    Spacer(minLength: 0)

                    AppButton(
                        title: revealPassword ? "MAIL_BRIDGE_HIDE_PASSWORD" : "MAIL_BRIDGE_SHOW_PASSWORD",
                        onClick: { revealPassword.toggle() },
                        type: .secondary,
                        size: .SM
                    )

                    AppButton(
                        title: copiedAll ? "MAIL_BRIDGE_COPIED" : "MAIL_BRIDGE_COPY_ALL",
                        onClick: { copyAll() },
                        type: .secondary,
                        size: .SM
                    )
                }
                .padding(EdgeInsets(top: 11, leading: 14, bottom: 11, trailing: 14))

                MailBridgeDivider()

                HStack(alignment: .top, spacing: 0) {
                    credentialColumn(.imap)
                    Rectangle().fill(Color.Gray10).frame(width: 1)
                    credentialColumn(.smtp)
                }
            }
        }
    }

    private func credentialColumn(_ kind: ProtocolKind) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: kind.symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.Primary)
                Text(kind.rawValue)
                    .font(.XSBold)
                    .foregroundColor(.Gray100)
                AppText(kind.captionKey)
                    .font(.XSRegular)
                    .foregroundColor(.Gray50)
            }
            .padding(.bottom, 6)

            ForEach(service.credentials.rows(for: kind)) { row in
                MailBridgeCredentialRow(
                    row: row,
                    isRevealed: revealPassword,
                    isCopied: copiedRowID == row.id,
                    onCopy: { copy(row) }
                )
            }
        }
        .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
