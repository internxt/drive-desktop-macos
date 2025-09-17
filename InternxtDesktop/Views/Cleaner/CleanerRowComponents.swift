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
    let checkboxState: CheckboxState
    let isHighlighted: Bool
    let onToggle: (CheckboxState) -> Void
    let onTap: () -> Void
    
    private var isDisabled: Bool {
        return category.size == 0 || !category.canAccess
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                guard !isDisabled else { return }
                
                let nextState: CheckboxState = switch checkboxState {
                case .unchecked: .checked
                case .checked: .unchecked
                case .mixed: .checked
                }
                onToggle(nextState)
            }) {
                CheckboxView(state: checkboxState)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 24, minHeight: 24)
            .contentShape(Rectangle())
            .disabled(isDisabled)
                        
            AppText(category.name)
                .font(.BaseRegular)
                .foregroundColor(isDisabled ? .secondary : .DefaultTextStrong)
            
            Spacer()
            
            HStack(spacing: 8) {
                if !isHighlighted {
                    AppText(formatFileSize(category.size))
                        .font(.BaseRegular)
                        .foregroundColor(isDisabled ? .secondary : .DefaultText)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17))
                        .foregroundColor(isDisabled ? .secondary : .Primary)
                }
            }
            .onTapGesture {
                guard !isDisabled else { return }
                onTap()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .opacity(isDisabled ? 0.5 : 1.0)
        .onTapGesture {
            guard !isDisabled else { return }
            onTap()
        }
    }
    
    private func formatFileSize(_ bytes: UInt64) -> String {
        if bytes == 0 {
            return "0 KB"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}


struct FileRow: View {
    let file: CleanupFile
    let checkboxState: CheckboxState
    let onToggle: (CheckboxState) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                let nextState: CheckboxState = switch checkboxState {
                case .unchecked: .checked
                case .checked: .unchecked
                case .mixed: .checked
                }
                onToggle(nextState)
            }) {
                CheckboxView(state: checkboxState)
            }
            .buttonStyle(.plain)
            .frame(minWidth: 24, minHeight: 24)
            .contentShape(Rectangle())
            
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

enum CheckboxState {
    case unchecked
    case checked
    case mixed
}

struct CheckboxView: View {
    let state: CheckboxState
    
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.clear)
                .frame(width: 16, height: 16)
            
            RoundedRectangle(cornerRadius: 3)
                .fill(backgroundColor)
                .frame(width: 16, height: 16)
            
            RoundedRectangle(cornerRadius: 3)
                .stroke(borderColor, lineWidth: 1)
                .frame(width: 16, height: 16)
            
            if state == .checked {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            } else if state == .mixed {
                Rectangle()
                    .fill(.white)
                    .frame(width: 8, height: 2)
            }
        }
        .frame(minWidth: 20, minHeight: 20)
        .contentShape(Rectangle())
    }
    
    private var backgroundColor: Color {
        switch state {
        case .unchecked: return .clear
        case .checked, .mixed: return .accentColor
        }
    }
    
    private var borderColor: Color {
        switch state {
        case .unchecked: return .secondary
        case .checked, .mixed: return .accentColor
        }
    }
}

