//
//  Utils.swift
//  SyncExtension
//
//  Created by Robert Garcia on 7/9/23.
//

import Foundation
import InternxtSwiftCore
import FileProvider

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


func getParentId(item: NSFileProviderItem, user: DriveUser) -> String {
    return item.parentItemIdentifier == .rootContainer ? String(user.root_folder_id) : item.parentItemIdentifier.rawValue
}

func generateDriveWebURL(isFile:Bool, uuid: String) -> URL{
    if isFile {
        return URL(string: "\(URLDictionary.DRIVE_WEB_FILE)\(uuid)")!
    }
    return URL(string: "\(URLDictionary.DRIVE_WEB_FOLDER)\(uuid)")!
}
