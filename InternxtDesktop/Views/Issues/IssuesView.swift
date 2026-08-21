//
//  IssuesView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 10/8/26.
//

import SwiftUI

struct IssuesView: View {

    @EnvironmentObject var issuesManager: IssuesManager
    @State private var selectedCategory: IssueCategory = .sync

    var body: some View {
        VStack(alignment: .center, spacing: 0) {

            Picker("", selection: $selectedCategory) {
                ForEach(IssueCategory.allCases) { category in
                    Text(category.localizedTitle).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 220)
            .padding(.vertical, 14)

            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .overlay(Color.Gray10)

     
            let visibleIssues = issuesManager.issues(for: selectedCategory)

            if visibleIssues.isEmpty {
                IssuesEmptyStateView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.Gray1)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 0) {
                        ForEach(visibleIssues) { issue in
                            IssueRowView(issue: issue)
                        }
                    }
                }
                .background(Color.Gray1)
            }

            if !issuesManager.allIssues.isEmpty {
                issuesFooter
            }
        }
        .frame(width: 540, height: 440)
        .background(Color.Surface)
    }

    private var issuesFooter: some View {
        HStack {
            Spacer()
            Button {
                withAnimation {
                    issuesManager.clearAll()
                }
            } label: {
                AppText("ISSUES_CLEAR_ALL")
                    .font(.XSMedium)
                    .foregroundColor(.Gray60)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 16)
        }
        .frame(height: 36)
        .background(Color.Surface)
        .overlay(
            Divider()
                .frame(maxWidth: .infinity, maxHeight: 1)
                .overlay(Color.Gray10),
            alignment: .top
        )
    }
}

