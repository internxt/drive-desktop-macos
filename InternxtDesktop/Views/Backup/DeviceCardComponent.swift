//
//  DeviceCardComponent.swift
//  InternxtDesktop
//
//  Created by Richard Ascanio on 1/9/24.
//

import SwiftUI

struct DeviceCardComponent: View {
    @Environment(\.colorScheme) var colorScheme
    var deviceName: String
    var isCurrentDevice: Bool
    var isLoading: Bool
    var lastUpdated: String?
    @Binding var progress: Double
    @State private var progressBarWidth: CGFloat = .zero

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if isCurrentDevice {
                    Image("apple")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.Gray40)
                        .frame(width: 32, height: 32)
                } else {
                    Image("backup_folder")
                        .resizable()
                        .frame(width: 32, height: 32)
                }

                VStack(alignment: .leading, spacing: 0) {
                    AppText(deviceName)
                        .font(.SMMedium)
                        .foregroundColor(.Gray80)

                    if isLoading {
                        ProgressFieldComponent()
                    } else {
                        Text("BACKUP_LAST_UPLOADED_\(lastUpdated ?? "")")
                            .font(.SMRegular)
                            .foregroundColor(.Gray50)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if isLoading {
                    AppText("\(Int(progress * 100))%")
                        .font(.LGMedium)
                        .foregroundColor(.Primary)
                        .hidden()
                }
            }

            if isLoading {
                // show progress bar
                ProgressView()
                    .progressViewStyle(LinearProgressViewStyle(tint: Color.Primary))
            }

        }
        .padding(16)
        .background(colorScheme == .dark ? Color.Gray5 : Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .inset(by: -0.5)
                .stroke(Color.Gray10, lineWidth: 1)
        )
    }
}

#Preview {
    DeviceCardComponent(deviceName: "", isCurrentDevice: true, isLoading: true, lastUpdated: "", progress: .constant(20))
}
