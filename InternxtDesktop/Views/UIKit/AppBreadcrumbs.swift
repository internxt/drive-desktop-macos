//
//  AppBreadcrumbs.swift
//  InternxtDesktop
//
//  Created by Robert Garcia on 26/7/24.
//

import SwiftUI

struct AppBreadcrumbLevel {
    let id: String
    let uuid: String?  
    let name: String
}
struct AppBreadcrumbs: View {
    let maxLevels: Int = 2
    let onLevelTap: (AppBreadcrumbLevel) -> Void
    @Binding var levels: [AppBreadcrumbLevel]
    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            let lastLevel = levels.last
            ForEach(levels, id: \.id) {level in
                let isLast = lastLevel?.id == level.id
                AppBreadcrumbLevelView(
                    level: level,
                    isLast: isLast,
                    onTap: {
                        self.onLevelTap(level)
                    }
                )
                if !isLast {getLevelSeparator()}
            }
        }.frame(height: 32)
        
    }
    
    
    func getLevelSeparator() -> some View {
        HStack {
            AppIcon(iconName: .ChevronRight,  size: 14,color: .Gray50)
        }
    }
   
}


struct AppBreadcrumbLevelView: View {
    let level: AppBreadcrumbLevel
    let isLast: Bool
    let onTap: () -> Void
    @State var isHovering = false
    var body: some View {
        
        HStack(spacing:0) {
            AppText(level.name).font(.BaseMedium).foregroundColor(isLast ? .Gray80 : .Gray50)
        }
        .padding(.horizontal, 6)
        .background(
            isHovering ? Color.Gray10 : Color.clear
        )
        .cornerRadius(6)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onHover(perform: { hovering in
            isHovering = hovering
        }).onTapGesture {
            onTap()
        }
    }
    
    
}


