//
//  Time.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation


public class Time {
    public static func dateFromISOString(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }

    public static func stringDateFromDate(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let stringDateFormatter = DateFormatter()
        stringDateFormatter.dateStyle = dateStyle
        stringDateFormatter.timeStyle = timeStyle

        return stringDateFormatter.string(from: date)
    }
}
