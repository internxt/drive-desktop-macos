//
//  AppIcon.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 31/8/23.
//

import SwiftUI
enum AppIconName: String {
    case Globe = "EB5A"
    case FolderSimple = "EB2C"
    case Gear = "EB44"
    case CheckCircle = "EA30"
    case Check = "EA32"
    case At = "E989"
    case ChatCircle = "EA29"
    case ChevronDown = "E9FD"
    case ChevronRight = "E9FF"
    case ChevronLeft = "E9F3"
    case Plus = "EC87"
    case Minus = "EBF9"
    case ClockCounterClockwise = "EA45"
    case WarningCircle = "EDBF"
}


struct AppIcon: View {
    
    private var iconName: AppIconName
    private var color: Color
    private var size: Int
    init(iconName: AppIconName, size: Int = 20, color: Color) {
        self.iconName = iconName
        self.size = size
        self.color = color
    }
    func getUnicode(code: String) -> String {
        let code = code // or whatever you got from the server
        let codeint = UInt32(code, radix: 16)!
        let c = UnicodeScalar(codeint)!
        return String(c)
    }
    var body: some View {
        Text(iconName.rawValue.unicode).font(.custom("Phosphor-Light", size: CGFloat(size))).foregroundColor(color)
    }
}

struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AppIcon(iconName: .Globe, size: 24, color: Color("Primary"))
    }
}
