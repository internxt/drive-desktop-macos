//
//  AppText.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 17/8/23.
//

import SwiftUI

extension AppText {
    func textStyle<Style: ViewModifier>(_ style: Style) -> some View {
        ModifiedContent(content: self, modifier: style)
    }
}

let AppTextFont: [String: Font] = [
    // SM Size
    "SM/Regular": Font.custom("NeueEinstellung-Regular", size: 14),
    "SM/Medium": Font.custom("NeueEinstellung-Medium", size: 14),
    "SM/SemiBold": Font.custom("NeueEinstellung-SemiBold", size: 14),
    "SM/Semibold": Font.custom("NeueEinstellung-SemiBold", size: 14),
    "SM/Bold": Font.custom("NeueEinstellung-Bold", size: 14),
    // Base Size
    "Base/Regular": Font.custom("NeueEinstellung-Regular", size: 16),
    "Base/Medium": Font.custom("NeueEinstellung-Medium", size: 16),
    "Base/SemiBold": Font.custom("NeueEinstellung-SemiBold", size: 16),
    "Base/Semibold": Font.custom("NeueEinstellung-SemiBold", size: 16),
    "Base/Bold": Font.custom("NeueEinstellung-Bold", size: 16),
    // LG Size
    "LG/Regular": Font.custom("NeueEinstellung-Regular", size: 18),
    "LG/Medium": Font.custom("NeueEinstellung-Medium", size: 18),
    "LG/SemiBold": Font.custom("NeueEinstellung-SemiBold", size: 18),
    "LG/Semibold": Font.custom("NeueEinstellung-SemiBold", size: 18),
    "LG/Bold": Font.custom("NeueEinstellung-Bold", size: 18),
    // XL Size
    "XL/Regular": Font.custom("NeueEinstellung-Regular", size: 20),
    "XL/Medium": Font.custom("NeueEinstellung-Medium", size: 20),
    "XL/SemiBold": Font.custom("NeueEinstellung-SemiBold", size: 20),
    "XL/Semibold": Font.custom("NeueEinstellung-SemiBold", size: 20),
    "XL/Bold": Font.custom("NeueEinstellung-Bold", size: 20),
    // 2XL Size
    "2XL/Regular": Font.custom("NeueEinstellung-Regular", size: 24),
    "2XL/Medium": Font.custom("NeueEinstellung-Medium", size: 24),
    "2XL/Semibold": Font.custom("NeueEinstellung-SemiBold", size: 24),
    "2XL/SemiBold": Font.custom("NeueEinstellung-SemiBold", size: 24),
    "2XL/Bold": Font.custom("NeueEinstellung-Bold", size: 24)
]


struct AppTextStyle: ViewModifier {
    let font: Font
    let foregroundColor: Color
    init(font: Font?,  foregroundColor: Color = Color("Highlight")){
        self.font = font ??  AppTextFont["Base/Medium"]!
        self.foregroundColor = foregroundColor
    }
    func body(content: Content) -> some View {
        content
            .font(self.font)
            .foregroundColor(self.foregroundColor)
    }
}



struct AppText: View {
    private let text: String
    init(_ text: String){
        self.text = text
    }
    var body: some View {
        Text(text)
    }
}

struct AppText_Previews: PreviewProvider {
    static var previews: some View {
        AppText("Preview").font(AppTextFont["2XL/Semibold"])
    }
}
