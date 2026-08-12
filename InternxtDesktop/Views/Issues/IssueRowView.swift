//
//  IssueRowView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/8/26.
//

import SwiftUI

struct IssueRowView: View {

    let issue: Issue

    private static let relativeDateFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {

                Image(getFileExtensionIconName(filenameWithExtension: issue.filename))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: issue.filename)
                        .font(.SMMedium)
                        .foregroundColor(.Gray100)
                        .lineLimit(1)
                        .help(issue.filename)

                    HStack(spacing: 4) {
                        AppText(issue.operation.localizedLabel)
                            .font(.XSRegular)
                            .foregroundColor(.Gray50)

                        if let desc = issue.errorDescription {
                            Text("·")
                                .font(.XSRegular)
                                .foregroundColor(.Gray40)
                            Text(verbatim: desc)
                                .font(.XSRegular)
                                .foregroundColor(.Gray50)
                                .lineLimit(1)
                                .help(desc)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    AppIcon(iconName: .WarningCircle, size: 20, color: .Red)
                    Text(Self.relativeDateFormatter.localizedString(for: issue.date, relativeTo: Date()))
                        .font(.XXSRegular)
                        .foregroundColor(.Gray40)
                }
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 56)

            Divider()
                .foregroundColor(.Gray10)
                .frame(height: 1)
        }
    }
}
