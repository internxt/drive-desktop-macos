//
//  ContentView.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 30/7/23.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center){
                HStack{
                    
                }.frame(height: 56)
                
            }.frame(maxWidth: .infinity).background(Color("Gray1"))
            Divider().frame(height: 1).background(Color("Gray10"))
            Spacer()
            Divider().frame(height: 1).background(Color("Gray10"))
            HStack{
                
            }.frame(height: 44)
        }.frame(width: 300, height: 400).background(Color.white).cornerRadius(10)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
