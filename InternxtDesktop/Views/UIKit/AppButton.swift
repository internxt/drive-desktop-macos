//
//  AppButton.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 17/8/23.
//

import SwiftUI


struct PrimaryAppButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .frame(height: 40)
            .padding(.horizontal, 20)
            .foregroundColor(configuration.isPressed ? Color.white : Color.white)
            .background(configuration.isPressed ? Color("Primary") : Color("Primary"))
            .cornerRadius(8)
            .font(AppTextFont["Base/Medium"])
            
    }
}


struct AppButton: View {
    private let title: String
    private let onClick: () -> Void
    init(title: String, onClick: @escaping () -> Void) {
        self.title = title
        self.onClick = onClick
    }
    var body: some View {
        
        Button(self.title) {
            self.onClick()
        }
        .buttonStyle(PrimaryAppButtonStyle())
       

    }
}

struct AppButton_Previews: PreviewProvider {
    static var previews: some View {
        AppButton(title: "Test button", onClick: {})
    }
}
