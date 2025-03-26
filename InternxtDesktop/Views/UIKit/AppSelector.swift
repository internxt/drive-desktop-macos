//
//  AppSelector.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 8/11/23.
//

import SwiftUI




enum AppSelectorSize {
    case SM
    case MD
}

struct AppSelectorOption: Identifiable {
    var id = UUID()
    var value: String
    var label: String
}

func getAppSelectorHeight(_ size: AppSelectorSize) -> CGFloat {
    switch size {
    case .SM:
        return 28
    case .MD:
        return 36
    }
}

func getAppSelectorFont(_ size: AppSelectorSize) -> Font {
    switch size {
    case .SM:
        return .SMMedium
    case .MD:
        return .BaseMedium
    }
}

enum AppSelectorPosition{
    case bottom
    case top
}

struct AppSelector: View {
    
    @State private var selectedOption: AppSelectorOption? = nil
    @State private var optionsVisible: Bool = false
    var size: AppSelectorSize = .MD
    var options: Array<AppSelectorOption>
    var initialValue: String?
    var placeholder: String = "Select"
    var position: AppSelectorPosition = .bottom
    var onSelectOption: (AppSelectorOption) -> Void
    var isDisabled: Bool = false
    
    var body: some View {
        return GeometryReader { geometry in
            ZStack{
                Color.Gray5.clipShape(RoundedRectangle(cornerRadius: 6))
                HStack{
                    AppText(selectedOption?.label ?? placeholder).font(getAppSelectorFont(self.size))
                    AppIcon(iconName: .ChevronDown, color: .Gray80)
                    
                }.padding(.horizontal,12)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.Gray10, lineWidth: 1)
            }.frame(minWidth:geometry.size.width, minHeight: getAppSelectorHeight(size) ).fixedSize(horizontal: true, vertical: true).contentShape(Rectangle()).onTapGesture {
                
                if !isDisabled {
                          withAnimation {
                              self.optionsVisible.toggle()
                          }
                      }

            }
            SelectorOptions(selectorWidth: geometry.size.width).offset(y: getAppSelectorHeight(size)).opacity(optionsVisible ? 1 : 0)
        }.frame(height: getAppSelectorHeight(size)).onTapBackground(enabled: optionsVisible) {
            withAnimation {
                optionsVisible = false
            }
        }.onAppear {
            if let initialValueUnwrapped = initialValue {
                let match = options.first(where: {$0.value == initialValueUnwrapped})
                selectedOption = match
            }
        }
        .opacity(isDisabled ? 0.5 : 1.0)
    }
    
    func SelectorOptions(selectorWidth: CGFloat) -> some View {
        return ZStack(alignment:.leading){
                Color.Gray5.clipShape(RoundedRectangle(cornerRadius: 6)).shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 32)
            VStack(alignment: .leading, spacing:0) {
                    ForEach(options) {option in
                        AppSelectorOptionView(
                            selectedOption: $selectedOption, option: option, size: size) {
                                self.selectOption(option)
                                withAnimation {
                                    optionsVisible = false
                                }
                            }
                        
                    }
                }.padding(.vertical, 6).frame(maxWidth: .infinity)
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.Gray10, lineWidth: 2)
            }.offset(y: getOffsetForPosition()).fixedSize().zIndex(100)
    }
    
    private func getOffsetForPosition() -> CGFloat {
        if position == .bottom {
            return 6
        }
        let optionSpacing = 0
        let optionHeight = 36
        let spacer = 6
        let totalOptionsHeight = options.count * (optionHeight + optionSpacing + spacer)
        
        return -CGFloat(CGFloat(totalOptionsHeight) + getAppSelectorHeight(size))
    }
    
    private func selectOption(_ option: AppSelectorOption) -> Void {
        selectedOption = option
        self.onSelectOption(option)
    }
    
    
}

struct AppSelectorOptionView: View {
    
    @State private var isHovering = false
    @Binding var selectedOption: AppSelectorOption?
    var option: AppSelectorOption
    var size: AppSelectorSize
    var onSelectOption: () -> Void
    
    private func isOptionSelected(_ option: AppSelectorOption) -> Bool {
        return option.value == selectedOption?.value
    }
    var body: some View {
        return HStack(spacing: 0){
            VStack(spacing: 0){
                if(isOptionSelected(option)) {
                    Image(systemName: "checkmark").foregroundColor(.Gray80)
                }
                 
            }.padding(.trailing, 6).frame(width: 24,height: 36 )
            AppText(option.label).font(getAppSelectorFont(size))
            Spacer()
        }.contentShape(Rectangle()).onTapGesture {
            self.onSelectOption()
            //self.selectOption(option)
        }.frame(maxWidth: .infinity).padding(.horizontal, 12).onHover{isHovering in
            self.isHovering = isHovering
        }.background(Color.Gray10.opacity(isHovering ? 1: 0))
    }
}
struct AppSelector_Previews: PreviewProvider {
    
    func handleOnSelectOption(option: AppSelectorOption) {
        
    }
    static var previews: some View {
        HStack(alignment: .top){
            AppSelector(
                options: [
                    AppSelectorOption(
                        value: "OptionA",
                        label: "OptionA"
                    ),
                    AppSelectorOption(
                        value: "OptionB",
                        label: "OptionB"
                    ),
                    AppSelectorOption(
                        value: "OptionC",
                        label: "OptionC"
                    )
                ]
                ){selectedOption in
                    
                }.padding(16)
        }.frame(height: 600)
    }
}

