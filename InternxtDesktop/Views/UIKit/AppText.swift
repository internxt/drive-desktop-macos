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
    // XS Size
    "XS/Regular": Font.custom("InstrumentSans-Regular", size: 12),
    "XS/Medium": Font.custom("InstrumentSans-Medium", size: 12),
    "XS/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 12),
    "XS/Semibold": Font.custom("InstrumentSans-SemiBold", size: 12),
    "XS/Bold": Font.custom("InstrumentSans-Bold", size: 12),
    // SM Size
    "SM/Regular": Font.custom("InstrumentSans-Regular", size: 14),
    "SM/Medium": Font.custom("InstrumentSans-Medium", size: 14),
    "SM/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 14),
    "SM/Semibold": Font.custom("InstrumentSans-SemiBold", size: 14),
    "SM/Bold": Font.custom("InstrumentSans-Bold", size: 14),
    // Base Size
    "Base/Regular": Font.custom("InstrumentSans-Regular", size: 16),
    "Base/Medium": Font.custom("InstrumentSans-Medium", size: 16),
    "Base/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 16),
    "Base/Semibold": Font.custom("InstrumentSans-SemiBold", size: 16),
    "Base/Bold": Font.custom("InstrumentSans-Bold", size: 16),
    // LG Size
    "LG/Regular": Font.custom("InstrumentSans-Regular", size: 18),
    "LG/Medium": Font.custom("InstrumentSans-Medium", size: 18),
    "LG/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 18),
    "LG/Semibold": Font.custom("InstrumentSans-SemiBold", size: 18),
    "LG/Bold": Font.custom("InstrumentSans-Bold", size: 18),
    // XL Size
    "XL/Regular": Font.custom("InstrumentSans-Regular", size: 20),
    "XL/Medium": Font.custom("InstrumentSans-Medium", size: 20),
    "XL/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 20),
    "XL/Semibold": Font.custom("InstrumentSans-SemiBold", size: 20),
    "XL/Bold": Font.custom("InstrumentSans-Bold", size: 20),
    // 2XL Size
    "2XL/Regular": Font.custom("InstrumentSans-Regular", size: 24),
    "2XL/Medium": Font.custom("InstrumentSans-Medium", size: 24),
    "2XL/Semibold": Font.custom("InstrumentSans-SemiBold", size: 24),
    "2XL/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 24),
    "2XL/Bold": Font.custom("InstrumentSans-Bold", size: 24),
    // 3XL Size
    "3XL/Regular": Font.custom("InstrumentSans-Regular", size: 30),
    "3XL/Medium": Font.custom("InstrumentSans-Medium", size: 30),
    "3XL/Semibold": Font.custom("InstrumentSans-SemiBold", size: 30),
    "3XL/SemiBold": Font.custom("InstrumentSans-SemiBold", size: 30),
    "3XL/Bold": Font.custom("InstrumentSans-Bold", size: 30)
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
        Text(LocalizedStringKey(text)).background(Color.clear)
    }
}

struct AppText_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            AppText("InstrumentSans-Regular").font(AppTextFont["2XL/Regular"])
            AppText("InstrumentSans-Medium").font(AppTextFont["2XL/Medium"])
            AppText("InstrumentSans-Semibold").font(AppTextFont["2XL/Semibold"])
            AppText("InstrumentSans-Bold").font(AppTextFont["2XL/Bold"])
        }.padding(16)
    }
}
