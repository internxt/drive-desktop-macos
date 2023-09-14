//
//  WidgetIconButtonView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 31/8/23.
//

import SwiftUI

struct WidgetIconButtonView: View {
    @Environment(\.colorScheme) var colorScheme
    @State private var hovering = false
    let iconName: AppIconName
    let onClick: () -> Void
    init(iconName: AppIconName, onClick: @escaping () -> Void) {
        self.iconName = iconName
        self.onClick = onClick
    }
    var body: some View {
        
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .opacity(hovering ? 1 : 0)
                .frame(width: 32, height: 32, alignment: .center)
                .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                .shadow(color: .black.opacity(0.1), radius: 1, x: 0, y: 1)
                
            RoundedRectangle(cornerRadius: 8).stroke(Color.Gray20.opacity(hovering ? 1 : 0), lineWidth: 2)
            VStack {

                VStack {
                    AppIcon(iconName: iconName, size: 22, color: .Gray80).padding(.horizontal, 5)
                }
                .frame(height: 32, alignment: .center)
            }
            .frame(width: 32, height: 32)
            .background(hovering ? colorScheme == .dark ? Color.Gray10 : Color.Surface :  colorScheme == .dark ? Color.Gray5 : Color.Gray1)
            .cornerRadius(8)
            .opacity(1)
                        
        }
        .frame(width: 32, height: 32)
        .onHover(perform: {isHovering in
            withAnimation {
                hovering = isHovering
            }
            
        })
        .onTapGesture {
            self.onClick()
        }
    }
}

struct WidgetIconButton_Previews: PreviewProvider {
    static var previews: some View {
        WidgetIconButtonView(iconName: .Globe, onClick: {}).padding(20)
    }
}
