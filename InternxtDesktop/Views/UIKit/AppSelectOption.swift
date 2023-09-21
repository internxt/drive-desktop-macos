//
//  AppSelectOption.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 6/9/23.
//

import SwiftUI



struct AppSelectOption: View {
    @State private var selectedNumber: Int = 0
    public var title: String
    var body: some View {
        AppButton(title: self.title, onClick: {}, type: .secondary, size: .MD)
    }
}

struct AppSelectOption_Previews: PreviewProvider {
    static var previews: some View {
        AppSelectOption(title: "Test")
    }
}
