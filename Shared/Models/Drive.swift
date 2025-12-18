//
//  Drive.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 26/9/23.
//

import Foundation

enum DriveItemStatus: String {
    case removed = "REMOVED"
    case exists = "EXISTS"
    case trashed = "TRASHED"
}

struct DriveFile {
    public let uuid: String
    public let plainName: String?
    public let name: String
    public let type: String?
    public let size: Int
    public let createdAt: Date
    public let updatedAt: Date
    public let folderId: Int
    public let status: DriveItemStatus
    public let fileId: String?
}
