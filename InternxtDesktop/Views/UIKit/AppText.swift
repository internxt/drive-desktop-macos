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

extension Font {
    // XXS
    static let XXSRegular = Font.custom("InstrumentSans-Regular", size: 10)
    static let XXSMedium = Font.custom("InstrumentSans-Medium", size: 10)
    static let XXSSemibold = Font.custom("InstrumentSans-SemiBold", size: 10)
    static let XXSBold = Font.custom("InstrumentSans-Bold", size: 10)
    // XS
    static let XSRegular = Font.custom("InstrumentSans-Regular", size: 12)
    static let XSMedium = Font.custom("InstrumentSans-Medium", size: 12)
    static let XSSemibold = Font.custom("InstrumentSans-SemiBold", size: 12)
    static let XSBold = Font.custom("InstrumentSans-Bold", size: 12)
    
    // SM Size
    static let SMRegular = Font.custom("InstrumentSans-Regular", size: 14)
    static let SMMedium = Font.custom("InstrumentSans-Medium", size: 14)
    static let SMSemibold = Font.custom("InstrumentSans-SemiBold", size: 14)
    static let SMBold = Font.custom("InstrumentSans-Bold", size: 14)
    
    // Base Size
    static let BaseRegular = Font.custom("InstrumentSans-Regular", size: 16)
    static let BaseMedium = Font.custom("InstrumentSans-Medium", size: 16)
    static let BaseSemibold = Font.custom("InstrumentSans-SemiBold", size: 16)
    static let BaseBold = Font.custom("InstrumentSans-Bold", size: 16)
   
    // LG Size
    static let LGRegular = Font.custom("InstrumentSans-Regular", size: 18)
    static let LGMedium = Font.custom("InstrumentSans-Medium", size: 18)
    static let LGSemibold = Font.custom("InstrumentSans-SemiBold", size: 18)
    static let LGBold = Font.custom("InstrumentSans-Bold", size: 18)
    // XL Size
    static let XLRegular = Font.custom("InstrumentSans-Regular", size: 20)
    static let XLMedium = Font.custom("InstrumentSans-Medium", size: 20)
    static let XLSemibold = Font.custom("InstrumentSans-SemiBold", size: 20)
    static let XLBold = Font.custom("InstrumentSans-Bold", size: 20)
    // 2XL Size
    static let XXLRegular = Font.custom("InstrumentSans-Regular", size: 24)
    static let XXLMedium = Font.custom("InstrumentSans-Medium", size: 24)
    static let XXLSemibold = Font.custom("InstrumentSans-SemiBold", size: 24)
    static let XXLBold = Font.custom("InstrumentSans-Bold", size: 24)
    // 3XL Size
    static let XXXLRegular = Font.custom("InstrumentSans-Regular", size: 30)
    static let XXXLMedium = Font.custom("InstrumentSans-Medium", size: 30)
    static let XXXLSemibold = Font.custom("InstrumentSans-SemiBold", size: 30)
    static let XXXLBold = Font.custom("InstrumentSans-Bold", size: 30)
}



struct AppTextStyle: ViewModifier {
    let font: Font
    let foregroundColor: Color
    init(font: Font?,  foregroundColor: Color = .Highlight){
        self.font = font ?? .BaseMedium
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
            AppText("InstrumentSans-Regular").font(.XXLRegular)
            AppText("InstrumentSans-Medium").font(.XXLMedium)
            AppText("InstrumentSans-Semibold").font(.XXLSemibold)
            AppText("InstrumentSans-Bold").font(.XXLBold)
        }.padding(16)
    }
}
