//
//  WidgetProgressBar.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct WidgetProgressBar: View {
    @Binding var progressBarWidth: CGFloat
    @Binding var progress: Double

    var body: some View {
        ZStack(alignment: .leading) {
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 100)
                    .fill(Color.Gray5)
                    .frame(maxWidth: .infinity, minHeight: 4, maxHeight: 4)
                    .onAppear {
                        progressBarWidth = proxy.size.width
                    }
            }

            RoundedRectangle(cornerRadius: 100)
                .fill(Color.Primary)
                .frame(width: progressBarWidth * progress, height: 4)
        }
        .frame(height: 5, alignment: .leading)
    }
}

#Preview {
    WidgetProgressBar(progressBarWidth: .constant(.zero), progress: .constant(20))
}
