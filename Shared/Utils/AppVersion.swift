//
//  AppVersion.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 3/11/26.
//

import Foundation

public struct AppVersion: Comparable, CustomStringConvertible, Equatable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public var description: String {
        return "\(major).\(minor).\(patch)"
    }

    public init(major: Int, minor: Int = 0, patch: Int = 0) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    public static func parse(_ string: String) -> AppVersion? {
        var cleanString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanString.hasPrefix("v") || cleanString.hasPrefix("V") {
            cleanString.removeFirst()
        }

        let parts = cleanString.split(separator: ".").compactMap { Int($0) }
        guard let major = parts.first else {
            return nil
        }

        let minor = parts.count > 1 ? parts[1] : 0
        let patch = parts.count > 2 ? parts[2] : 0

        return AppVersion(major: major, minor: minor, patch: patch)
    }

    public static func current() -> AppVersion? {
        guard let versionString = Bundle.main.releaseVersionNumber else {
            return nil
        }
        return parse(versionString)
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        if lhs.major != rhs.major {
            return lhs.major < rhs.major
        }
        if lhs.minor != rhs.minor {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }


    public static func isDeprecated(current: AppVersion, minimumSupported: AppVersion) -> Bool {
        if current.major < minimumSupported.major {
            return true
        }

        if current.major == minimumSupported.major && current.minor < minimumSupported.minor {
            return true
        }

        return false
    }
}
