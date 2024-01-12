//
//  ProgressFieldComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct ProgressFieldComponent: View {
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.up.circle.fill")
                .resizable()
                .frame(width: 16, height: 16)
                .foregroundColor(.Primary)

            AppText("BACKUP_BACKING_UP")
                .font(.SMMedium)
                .foregroundColor(.Primary)
        }
    }
}

#Preview {
    ProgressFieldComponent()
}
