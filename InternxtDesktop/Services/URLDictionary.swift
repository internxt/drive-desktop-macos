//
//  URLProvider.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 17/8/23.
//

import Foundation

struct URLDictionary {
    public static var DRIVE_WEB = URL(string: "https://drive.internxt.com")!
    public static var WEB_AUTH_SIGNIN = URL(string:"https://drive.internxt.com/login?universalLink=true")!
    public static var WEB_AUTH_SIGNUP = URL(string:"https://drive.internxt.com/new?universalLink=true")!
    public static var LEARN_MORE_ABOUT_INTERNXT_DRIVE = URL(string:"https://internxt.com/drive")!
    public static var UPGRADE_PLAN = URL(string:"https://drive.internxt.com/preferences?tab=plans")!
    public static var HELP_CENTER = URL(string:"https://help.internxt.com")!
    public static var BACKUPS_WEB = URL(string: "https://drive.internxt.com/backups")!
    public static var DRIVE_WEB_FILE = "https://drive.internxt.com/file/"
}
