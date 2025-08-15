//
//  CleanupView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 15/8/25.
//

import SwiftUI

struct CleanupView: View {
    @State private var selectedCategories: Set<String> = ["Downloads", "Screenshots", "Mail attachments"]
    @State private var selectedCategoryForPreview: String? = nil
    @State private var selectedFiles: Set<String> = []
    
    let categories = [
        ("Downloads", "81.8 GB"),
        ("Installation files", "81.8 GB"),
        ("Screenshots", "81.8 GB"),
        ("Mail attachments", "81.8 GB")
    ]
    
 
    let categoryFiles: [String: [(String, String)]] = [
        "Downloads": [
            ("picture1", "81.8 GB"),
            ("picture2", "45.2 GB"),
            ("document.pdf", "12.3 GB"),
            ("video.mp4", "2.1 GB"),
            ("archive.zip", "156.7 MB")
        ],
        "Screenshots": [
            ("Screenshot 2024-01-15.png", "2.1 MB"),
            ("Screenshot 2024-01-14.png", "1.8 MB"),
            ("Screenshot 2024-01-13.png", "2.3 MB"),
            ("Screenshot 2024-01-12.png", "1.9 MB")
        ],
        "Mail attachments": [
            ("Invoice.pdf", "512 KB"),
            ("Presentation.pptx", "15.2 MB"),
            ("Photo.jpg", "3.1 MB"),
            ("Contract.docx", "245 KB")
        ],
        "Installation files": [
            ("Xcode.dmg", "12.1 GB"),
            ("Chrome.dmg", "156.7 MB"),
            ("Photoshop.dmg", "2.8 GB"),
            ("Office.pkg", "1.2 GB")
        ]
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
              
                VStack(alignment: .leading, spacing: 0) {
                  
                    HStack {
                        Text("Álvaro's Mac...")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            
                            Button("Select all") {
                                if selectedCategories.count == categories.count {
                                    selectedCategories.removeAll()
                                } else {
                                    selectedCategories = Set(categories.map { $0.0 })
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.blue)
                            .font(.system(size: 13))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    
                    Divider()
                        .padding(.horizontal, 16)
              
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                                CategoryRow(
                                    name: category.0,
                                    size: category.1,
                                    isSelected: selectedCategories.contains(category.0),
                                    isHighlighted: selectedCategoryForPreview == category.0,
                                    onToggle: { isSelected in
                                        if isSelected {
                                            selectedCategories.insert(category.0)
                                        } else {
                                            selectedCategories.remove(category.0)
                                        }
                                    },
                                    onTap: {
                                        selectedCategoryForPreview = category.0
                                        selectedFiles.removeAll()
                                      
                                        if selectedCategories.contains(category.0) {
                                            if let files = categoryFiles[category.0] {
                                                selectedFiles = Set(files.map { $0.0 })
                                            }
                                        }
                                    }
                                )
                                .background(Color.clear)
                                
                                if index < categories.count - 1 {
                                    Divider()
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                    }
                    .frame(height: 280)
                }
                .frame(width: selectedCategoryForPreview != nil ? 240 : 320)
                
                if selectedCategoryForPreview != nil {
                 
                    Rectangle()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 1)
                    
                  
                    VStack(alignment: .leading, spacing: 0) {
                      
                        HStack {
                            Image(systemName: "chevron.right.2")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 14))
                                
                                Button("Select all") {
                                    if let files = categoryFiles[selectedCategoryForPreview!] {
                                        if selectedFiles.count == files.count {
                                            selectedFiles.removeAll()
                                        } else {
                                            selectedFiles = Set(files.map { $0.0 })
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                                .foregroundColor(.blue)
                                .font(.system(size: 13))
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 12)
                        
                        Divider()
                            .padding(.horizontal, 16)
                        
                      
                        ScrollView(.vertical, showsIndicators: true) {
                            LazyVStack(spacing: 0) {
                                if let files = categoryFiles[selectedCategoryForPreview!] {
                                    ForEach(Array(files.enumerated()), id: \.offset) { index, file in
                                        FileRow(
                                            name: file.0,
                                            size: file.1,
                                            isSelected: selectedFiles.contains(file.0)
                                        ) { isSelected in
                                            if isSelected {
                                                selectedFiles.insert(file.0)
                                            } else {
                                                selectedFiles.remove(file.0)
                                            }
                                        }
                                        
                                        if index < files.count - 1 {
                                            Divider()
                                                .padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(height: 280)
                    }
                    .frame(width: 350)
                } else {
                    Divider()
                    
                    
                    VStack(spacing: 0) {
                       
                     
                        
          
                    }
                    .frame(width: 270)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
          
            Button("Clean up") {
                
                if selectedCategoryForPreview != nil {
                    print("Cleaning up selected files: \(selectedFiles)")
                } else {
                    print("Cleaning up selected categories: \(selectedCategories)")
                }
            }
            .buttonStyle(DefaultButtonStyle())
            .foregroundColor(.white)
            .font(.system(size: 14, weight: .medium))
            .frame(height: 32)
            .frame(minWidth: 100)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.blue)
            )
            .padding(.bottom, 20)
        }
        .frame(width: 630, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onTapGesture {
            
            if selectedCategoryForPreview != nil {
                selectedCategoryForPreview = nil
                selectedFiles.removeAll()
            }
        }
    }
    
    private var storageSegments: [(startAngle: Double, endAngle: Double, color: Color)] {
        let colors: [Color] = [.blue, .orange, .pink, .green]
        let segmentSize = 0.2
        
        return colors.enumerated().map { index, color in
            let start = Double(index) * segmentSize
            let end = start + segmentSize
            return (startAngle: start, endAngle: end, color: color)
        }
    }
}

struct CategoryRow: View {
    let name: String
    let size: String
    let isSelected: Bool
    let isHighlighted: Bool
    let onToggle: (Bool) -> Void
    let onTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
          
            Button(action: {
                onToggle(!isSelected)
            }) {
                RoundedRectangle(cornerRadius: 3)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isSelected ? .blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? Color.blue : Color.primary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
          
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
        
            HStack(spacing: 8) {
                if !isHighlighted {
                    Text(size)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isHighlighted ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

struct FileRow: View {
    let name: String
    let size: String
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
          
            Button(action: {
                onToggle(!isSelected)
            }) {
                RoundedRectangle(cornerRadius: 3)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isSelected ? .blue : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(isSelected ? Color.blue : Color.primary.opacity(0.3), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(PlainButtonStyle())
            
         
            Text(name)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
          
            Text(size)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle(!isSelected)
        }
    }
}

#Preview {
    CleanupView()
}
