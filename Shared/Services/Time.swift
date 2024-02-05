//
//  Time.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/8/23.
//

import Foundation


public class Time {
    public static func dateFromISOString(_ dateString: String) -> Date? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        
        return dateFormatter.date(from: dateString)
    }

    public static func stringDateFromDate(_ date: Date, dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        let stringDateFormatter = DateFormatter()
        stringDateFormatter.dateStyle = dateStyle
        stringDateFormatter.timeStyle = timeStyle

        return stringDateFormatter.string(from: date)
    }
}
