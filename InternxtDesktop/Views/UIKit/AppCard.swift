//
//  AppCard.swift
//  InternxtDesktop
//
//  Created by Xavier Abad Gomez on 23/11/2026.
//

import SwiftUI

private let appCardCornerRadius: CGFloat = 12

struct AppCard<Content: View>: View {
    var fill: Color = .Gray5
    var stroke: Color = .Gray10
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: appCardCornerRadius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: appCardCornerRadius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1)
            )
    }
}

struct AppDivider: View {
    var color: Color = .Gray10
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

struct AppGlyph: View {
    private enum Source {
        case system(String)
        case asset(String)
    }

    private let source: Source
    var tint: Color = .Gray50
    var size: CGFloat = 42

    init(systemName: String, tint: Color = .Gray50, size: CGFloat = 42) {
        self.source = .system(systemName)
        self.tint = tint
        self.size = size
    }

    init(asset: String, tint: Color = .Gray50, size: CGFloat = 42) {
        self.source = .asset(asset)
        self.tint = tint
        self.size = size
    }

    var body: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(Color.Secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.Gray10, lineWidth: 1)
            )
            .overlay(icon)
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private var icon: some View {
        switch source {
        case .system(let name):
            Image(systemName: name)
                .font(.system(size: size * 0.4))
                .foregroundColor(tint)
        case .asset(let name):
            Image(name)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
                .foregroundColor(tint)
        }
    }
}
