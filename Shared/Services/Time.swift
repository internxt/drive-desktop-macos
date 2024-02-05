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

    public static func stringDateFromISOString(_ dateString: String) -> String {
        let date = Time.dateFromISOString(dateString)

        guard let date = date else {
            return ""
        }
        let stringDateFormatter = DateFormatter()
        stringDateFormatter.dateStyle = .long
        stringDateFormatter.timeStyle = .short

        return stringDateFormatter.string(from: date)
    }
}
