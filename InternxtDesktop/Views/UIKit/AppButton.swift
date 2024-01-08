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
    case secondary
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
        return .SMMedium
    case .MD:
        return .BaseMedium
    case .LG:
        return .BaseMedium
    }
}



struct PrimaryAppButtonStyle: ButtonStyle {
    public var size: AppButtonSize
    @Binding public var isEnabled: Bool

    func getForeroundColor(configuration: Self.Configuration) -> Color {
        if !isEnabled {
            return Color.white.opacity(0.5)
        }
        return .white
    }

    func getBackgroundColor(configuration: Self.Configuration) -> Color {
        if !isEnabled {
            return Color.Gray30
        }
        return configuration.isPressed ? Color.PrimaryDark : Color.Primary
    }

    func makeBody(configuration: Self.Configuration) -> some View {
        
        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .foregroundColor(getForeroundColor(configuration: configuration))
            .background(getBackgroundColor(configuration: configuration))
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
    }
}


struct SecondaryAppButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) var colorScheme
    public var size: AppButtonSize
    
    private func getForegroundColor(_ config: Self.Configuration) -> Color {
        if colorScheme == .dark {
            return config.isPressed ? Color.Gray10 : Color.Gray5
        } else {
            return config.isPressed ? Color.Gray1 : Color.Surface
        }
    }
    func makeBody(configuration: Self.Configuration) -> some View {
        
        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .background(getForegroundColor(configuration))
            .foregroundColor(Color.Gray80)
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(Color.Gray10, lineWidth: 1)
            )
            
    }
}

struct AppButton: View {
    public let title: String
    public let onClick: () -> Void
    public var type: AppButtonType = .primary
    public var size: AppButtonSize = .MD
    public var icon: AppIconName?
    @Binding public var isEnabled: Bool

    init(title: String, onClick: @escaping () -> Void, type: AppButtonType = .primary, size: AppButtonSize = .MD, isEnabled: Binding<Bool> = .constant(true)) {
        self.title = title
        self.onClick = onClick
        self.type = type
        self.size = size
        self._isEnabled = isEnabled
    }

    init(icon: AppIconName, title: String, onClick: @escaping () -> Void, type: AppButtonType = .primary, size: AppButtonSize = .MD, isEnabled: Binding<Bool> = .constant(true)) {
        self.title = title
        self.icon = icon
        self.onClick = onClick
        self.type = type
        self.size = size
        self._isEnabled = isEnabled
    }

    var body: some View {
        
        switch self.type {
        case .primary:
            if let icon = icon {
                Button(action: {
                    self.onClick()
                }, label: {
                    AppIcon(iconName: icon, color: .white)
                })
                .buttonStyle(PrimaryAppButtonStyle(size: self.size, isEnabled: $isEnabled))
            } else {
                Button(LocalizedStringKey(self.title)) {
                    self.onClick()
                }
                .buttonStyle(PrimaryAppButtonStyle(size: self.size, isEnabled: $isEnabled))
            }
        case .secondary:
            if let icon = icon {
                Button(action: {
                    self.onClick()
                }, label: {
                    AppIcon(iconName: icon, color: .Gray80)
                })
                .buttonStyle(SecondaryAppButtonStyle(size: self.size))
            } else {
                Button(LocalizedStringKey(self.title)) {
                    self.onClick()
                }
                .buttonStyle(SecondaryAppButtonStyle(size: self.size))
            }
        }

    }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        HStack {
            VStack(alignment: .leading) {
                AppText("Primary button")
                AppButton(title: "Button SM", onClick: {}, size: .SM)
                AppButton(icon: .Gear, title: "", onClick: {}, size: .SM)
                AppButton(title: "Button LG", onClick: {}, size: .LG)
            }.padding(20)
            VStack(alignment: .leading) {
                AppText("Secondary white button")
                AppButton(title: "Button SM", onClick: {}, type: .secondary, size: .SM)
                AppButton(icon: .Gear, title: "", onClick: {}, type: .secondary, size: .SM)
                AppButton(title: "Button MD", onClick: {},type: .secondary, size: .MD)
                AppButton(title: "Button LG", onClick: {}, type: .secondary, size: .LG)
            }.padding(20)
        }
    
        
        
    }
}
