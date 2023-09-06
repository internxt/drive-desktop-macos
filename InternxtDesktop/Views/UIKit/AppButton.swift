//
//  AppButton.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 17/8/23.
//

import SwiftUI


enum AppButtonSize {
    case SM
    case MD
    case LG
}

enum AppButtonType {
    case primary
    case secondaryWhite
}

func getHeightBySize(size: AppButtonSize) -> CGFloat {
    switch size {
    case .SM:
        return 28
    case .MD:
        return 32
    case .LG:
        return 40
    }
}

func getPaddingBySize(size: AppButtonSize) -> CGFloat {
    switch size {
    case .SM:
        return 12
    case .MD:
        return 14
    case .LG:
        return 20
    }
}

func getTextFontBySize(size: AppButtonSize) -> Font? {
    switch size {
    case .SM:
        return AppTextFont["SM/Medium"]
    case .MD:
        return AppTextFont["Base/Medium"]
    case .LG:
        return AppTextFont["Base/Medium"]
    }
}



struct PrimaryAppButtonStyle: ButtonStyle {
    public var size: AppButtonSize
    func makeBody(configuration: Self.Configuration) -> some View {
        
        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .foregroundColor(configuration.isPressed ? Color.white : Color.white)
            .background(configuration.isPressed ? Color("PrimaryDark") : Color("Primary"))
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
    }
}


struct SecondaryWhiteAppButtonStyle: ButtonStyle {
    public var size: AppButtonSize
    func makeBody(configuration: Self.Configuration) -> some View {
        let bgColor = Color("Secondary")
        let bgColorPressed = Color("Secondary")
        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .foregroundColor(Color("Gray80"))
            .background(configuration.isPressed ? bgColorPressed : bgColor)
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(Color("Gray10"), lineWidth: 1)
            )
            
    }
}

struct AppButton: View {
    public let title: String
    public let onClick: () -> Void
    public var type: AppButtonType = .primary
    public var size: AppButtonSize = .MD
    

    var body: some View {
        
        switch self.type {
        case .primary:
            Button(LocalizedStringKey(self.title)) {
                self.onClick()
            }
            .buttonStyle(PrimaryAppButtonStyle(size: self.size))
        case .secondaryWhite:
            Button(LocalizedStringKey(self.title)) {
                self.onClick()
            }
            .buttonStyle(SecondaryWhiteAppButtonStyle(size: self.size))
        }
        
       

    }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            VStack(alignment: .leading) {
                AppText("Primary button")
                AppButton(title: "Button SM", onClick: {}, size: .SM)
                AppButton(title: "Button MD", onClick: {}, size: .MD)
                AppButton(title: "Button LG", onClick: {}, size: .LG)
            }.padding(20)
            VStack(alignment: .leading) {
                AppText("Secondary white button")
                AppButton(title: "Button SM", onClick: {}, type: .secondaryWhite, size: .SM)
                AppButton(title: "Button MD", onClick: {},type: .secondaryWhite, size: .MD)
                AppButton(title: "Button LG", onClick: {}, type: .secondaryWhite, size: .LG)
            }.padding(20)
        }
    
        
        
    }
}
