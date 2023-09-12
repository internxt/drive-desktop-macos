//
//  Utils.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/9/23.
//

import Foundation

func dateToAnchor(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short

    return formatter.string(from: date)
}

func anchorToDate(_ string: String) -> Date? {
    let formatter = DateFormatter()
    formatter.dateStyle = .long
    formatter.timeStyle = .short
    return formatter.date(from: string)
}
