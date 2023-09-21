//
//  AppCheckbox.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/9/23.
//

import SwiftUI
struct AppCheckboxStyle: ToggleStyle {

    func makeBody(configuration: Self.Configuration) -> some View {

        return HStack {
            
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(configuration.isOn ? Color.clear : Color.Gray30, lineWidth: 1)
                    .frame(width:20, height:20)
                    .zIndex(10)
                Image(systemName: "checkmark")
                    .font(.system(size: 12.0).bold()).foregroundColor(configuration.isOn ? Color.white : Color.clear)
                .frame(width: 20, height: 20)
                .background(configuration.isOn ? Color.Primary : Color.Surface)
                .cornerRadius(4)
                
                    
            }
            configuration.label.font(.BaseMedium)
        }
        .onTapGesture { configuration.isOn.toggle() }

    }
}
struct AppCheckbox: View {
    public let label: String
    @Binding public var checked: Bool
    
    var body: some View {
        Toggle(isOn: $checked) {
            AppText(self.label)
        }
        .toggleStyle(AppCheckboxStyle())
    }
}

struct AppCheckbox_Previews: PreviewProvider {
    
    static var previews: some View {
        Group{
            AppCheckbox(label: "I'm checked", checked: .constant(true))
            AppCheckbox(label: "I'm unchecked", checked: .constant(false))
        }.padding(15)
        
    }
}
