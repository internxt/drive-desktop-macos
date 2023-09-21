//
//  Date.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 20/9/23.
//

import Foundation

extension Date {
    func timeAgoDisplay() -> String {
           let formatter = RelativeDateTimeFormatter()
           formatter.unitsStyle = .full
           return formatter.localizedString(for: self, relativeTo: Date())
    }
}
