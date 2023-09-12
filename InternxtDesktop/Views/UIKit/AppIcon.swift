//
//  AppIcon.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 31/8/23.
//

import SwiftUI
enum AppIconName: String {
    case Globe = "EB5B"
    case FolderSimple = "EB2C"
    case Gear = "EB43"
    case CheckCircle = "EA31"
    case Check = "EA30"
    case At = "E989"
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
        Text(iconName.rawValue.unicode).font(.custom("Phosphor", size: CGFloat(size))).foregroundColor(color)
    }
}

struct AppIcon_Previews: PreviewProvider {
    static var previews: some View {
        AppIcon(iconName: .Globe, size: 24, color: Color("Primary"))
    }
}
