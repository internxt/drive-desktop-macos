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

            categoryPicker
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 12)

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

  

    private var categoryPicker: some View {
        HStack(spacing: 4) {
            ForEach(IssueCategory.allCases) { category in
                categoryTab(for: category)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func categoryTab(for category: IssueCategory) -> some View {
        let isSelected = selectedCategory == category
        let count = issuesManager.issues(for: category).count

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCategory = category
            }
        } label: {
            HStack(spacing: 6) {
                AppText(category.localizedTitle)
                    .font(isSelected ? .SMMedium : .SMRegular)
                    .foregroundColor(isSelected ? .Gray100 : .Gray60)

                if count > 0 {
                    Text("\(count)")
                        .font(.XXSMedium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(Color.Red)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.Gray10 : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("issuesTab_\(category.rawValue)")
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

