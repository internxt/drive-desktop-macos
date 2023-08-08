//
//  AppTextInput.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 4/8/23.
//

import SwiftUI

struct AppTextInput: View {
    @State var text = ""
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search...", text: $text)
        }
        
    }
}

struct AppTextInput_Previews: PreviewProvider {
    static var previews: some View {
        AppTextInput()
    }
}
