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
    case danger
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
    public var isEnabled: Bool
    public var isExpanded: Bool

    func getForeroundColor(configuration: Self.Configuration) -> Color {
        if !isEnabled {
            return Color.white.opacity(0.75)
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

        return configuration
            .label
            .frame(height: getHeightBySize(size: self.size))
            .frame(maxWidth: isExpanded ? .infinity : nil)
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
    public var isEnabled: Bool
    public var isExpanded: Bool

    private func getBackgroundColor(_ config: Self.Configuration) -> Color {
        if colorScheme == .dark {
            return config.isPressed ? Color.Gray10 : Color.Gray5
        } else {
            return config.isPressed ? Color.Gray1 : .white
        }
    }

    private func getForegroundColor() -> Color {
        if !isEnabled {
            return Color.Gray30
        }
        return Color.Gray80
    }

    private func getStrokeColor() -> Color {
        if !isEnabled {
            return Color.Gray5
        }

        return Color.Gray10
    }

    func makeBody(configuration: Self.Configuration) -> some View {

        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .frame(maxWidth: isExpanded ? .infinity : nil)
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .background(getBackgroundColor(configuration))
            .foregroundColor(getForegroundColor())
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
            .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .inset(by: -0.5)
                    .stroke(getStrokeColor(), lineWidth: 1)
            )

    }
}

struct DangerAppButtonStyle: ButtonStyle {
    public var size: AppButtonSize
    public var isExpanded: Bool

    func makeBody(configuration: Self.Configuration) -> some View {

        return configuration.label
            .frame(height: getHeightBySize(size: self.size))
            .frame(maxWidth: isExpanded ? .infinity : nil)
            .padding(.horizontal, getPaddingBySize(size: self.size))
            .foregroundColor(.white)
            .background(Color.Red)
            .cornerRadius(8)
            .font(getTextFontBySize(size: self.size))
    }
}

struct AppButton: View {
    public let title: String
    public let onClick: () -> Void
    public var type: AppButtonType = .primary
    public var size: AppButtonSize = .MD
    public var icon: AppIconName?
    public var isEnabled: Bool
    public var isExpanded: Bool

    init(title: String, onClick: @escaping () -> Void, type: AppButtonType = .primary, size: AppButtonSize = .MD, isEnabled: Bool = true, isExpanded: Bool = false) {
        self.title = title
        self.onClick = onClick
        self.type = type
        self.size = size
        self.isEnabled = isEnabled
        self.isExpanded = isExpanded
    }

    init(icon: AppIconName, title: String, onClick: @escaping () -> Void, type: AppButtonType = .primary, size: AppButtonSize = .MD, isEnabled: Bool = true, isExpanded: Bool = false) {
        self.title = title
        self.icon = icon
        self.onClick = onClick
        self.type = type
        self.size = size
        self.isEnabled = isEnabled
        self.isExpanded = isExpanded
    }

    var body: some View {

        switch self.type {
        case .primary:
            if let icon = icon {
                Button(action: {
                    self.onClick()
                }, label: {
                    AppIcon(iconName: icon, color: .white.opacity(isEnabled ? 1 : 0.5))
                })
                .buttonStyle(PrimaryAppButtonStyle(size: self.size, isEnabled: isEnabled, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
            } else {
                Button(LocalizedStringKey(self.title)) {
                    self.onClick()
                }
                .buttonStyle(PrimaryAppButtonStyle(size: self.size, isEnabled: isEnabled, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
            }
        case .secondary:
            if let icon = icon {
                Button(action: {
                    self.onClick()
                }, label: {
                    AppIcon(iconName: icon, color: .Gray80.opacity(isEnabled ? 1 : 0.5))
                })
                .buttonStyle(SecondaryAppButtonStyle(size: self.size, isEnabled: isEnabled, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
            } else {
                Button(LocalizedStringKey(self.title)) {
                    self.onClick()
                }
                .buttonStyle(SecondaryAppButtonStyle(size: self.size, isEnabled: isEnabled, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
            }
        case .danger:
            if let icon = icon {
                Button(action: {
                    self.onClick()
                }, label: {
                    AppIcon(iconName: icon, color: .Gray80)
                })
                .buttonStyle(DangerAppButtonStyle(size: self.size, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
            } else {
                Button(LocalizedStringKey(self.title)) {
                    self.onClick()
                }
                .buttonStyle(DangerAppButtonStyle(size: self.size, isExpanded: self.isExpanded))
                .disabled(!isEnabled)
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
                AppButton(title: "Button MD", onClick: {}, size: .SM)
                AppButton(title: "Button MD", onClick: {}, size: .SM, isEnabled: false)
                AppButton(title: "Button LG", onClick: {}, size: .LG)
                AppButton(title: "Button LG", onClick: {}, size: .LG, isExpanded: true)
            }.padding(20)
            VStack(alignment: .leading) {
                AppText("Secondary white button")
                AppButton(title: "Button SM", onClick: {}, type: .secondary, size: .SM)
                AppButton(icon: .Gear, title: "", onClick: {}, type: .secondary, size: .SM)
                AppButton(icon: .Gear, title: "", onClick: {}, type: .secondary, size: .SM, isEnabled: false)
                AppButton(title: "Button MD", onClick: {},type: .secondary, size: .MD)
                AppButton(title: "Button MD", onClick: {},type: .secondary, size: .MD, isEnabled: false)
                AppButton(title: "Button LG", onClick: {}, type: .secondary, size: .LG)
            }.padding(20)
            VStack(alignment: .leading) {
                AppText("Danger button")
                AppButton(title: "Button SM", onClick: {}, type: .danger, size: .SM)
                AppButton(title: "Button MD", onClick: {},type: .danger, size: .MD)
                AppButton(title: "Button LG", onClick: {}, type: .danger, size: .LG)
            }.padding(20)
        }
        .background(Color.Surface)


    }
}
