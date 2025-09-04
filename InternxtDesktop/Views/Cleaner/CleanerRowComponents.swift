//
//  CleanerRowComponents.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//

import Foundation
import SwiftUI

struct CategoryRow: View {
    let category: CleanupCategory
    let isSelected: Bool
    let isHighlighted: Bool
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    onToggle(newValue)
                }
            ))
            .toggleStyle(CheckboxToggleStyle())
            .labelsHidden()
                        
            AppText(category.name)
                .font(.BaseRegular)
                .foregroundColor(.DefaultTextStrong)
            
            Spacer()
            
            HStack(spacing: 8) {
                if !isHighlighted {
                    AppText(formatFileSize(category.size))
                        .font(.BaseRegular)
                        .foregroundColor(.DefaultText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17))
                        .foregroundColor(.Primary)
                }
            }
            .onTapGesture {
                onTap()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .opacity(category.canAccess ? 1.0 : 0.7)
    }
    
    private func formatFileSize(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}


struct FileRow: View {
    let file: CleanupFile
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    onToggle(newValue)
                }
            ))
            .toggleStyle(CheckboxToggleStyle())
            .labelsHidden()
            
            Text(file.name)
                .font(.BaseRegular)
                .foregroundColor(.DefaultTextStrong)
                .lineLimit(1)
                .truncationMode(.middle)
            
            Spacer()
            
            Text(formatFileSize(Int64(file.size)))
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
