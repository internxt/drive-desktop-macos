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
            ZStack {
                mainContentView
                
                if selectedCategoryForPreview != nil {
                    HStack {
                        Spacer()
                        fileListView
                    }
                    .transition(.move(edge: .trailing))
                    .animation(.easeInOut(duration: 0.3), value: selectedCategoryForPreview)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.DefaultBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Spacer()
            
            AppButton(title: "Clean up", onClick: {
                if selectedCategoryForPreview != nil {
                    print("Cleaning up selected files: \(selectedFiles)")
                } else {
                    print("Cleaning up selected categories: \(selectedCategories)")
                }
            })
            .padding(.bottom, 20)
        }
        .frame(width: 630, height: 400)
        .onTapGesture {
            if selectedCategoryForPreview != nil {
                selectedCategoryForPreview = nil
                selectedFiles.removeAll()
            }
        }
        
    }
    
    private var mainContentView: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    AppText("Álvaro's Mac...")
                        .font(.LGMedium)
                        .foregroundColor(.Gray100)
                    
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
                        .font(.BaseRegular)
                        .foregroundColor(.DefaultText)
                      
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
            .frame(width: 320)
            
            Divider()
            
            VStack(spacing: 0) {
                StorageMeterView()
            }
            .frame(width: 270)
        }
    }
    
    private var fileListView: some View {
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
                    .font(.BaseRegular)
                    .foregroundColor(.DefaultText)
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
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: -5, y: 0)
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
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { newValue in
                    onToggle(newValue)
                }
            ))
            .toggleStyle(CheckboxToggleStyle())
            .labelsHidden()
            
            AppText(name)
                .font(.BaseRegular)
                .foregroundColor(.DefaultTextStrong)
            
            Spacer()
            
            HStack(spacing: 8) {
                if !isHighlighted {
                    AppText(size)
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
    }
}

struct FileRow: View {
    let name: String
    let size: String
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
            
            Text(name)
                .font(.BaseRegular)
                .foregroundColor(.DefaultTextStrong)
            
            Spacer()
            
            Text(size)
                .font(.BaseRegular)
                .foregroundColor(.DefaultText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

#Preview {
    CleanupView()
}




struct StorageMeterView: View {
    let totalStorage: Double = 17.2
    let categories = [
        StorageCategory(name: "Fotos", value: 4.5, color: .blue),
        StorageCategory(name: "Apps", value: 3.2, color: .orange),
        StorageCategory(name: "Videos", value: 2.8, color: .pink),
        StorageCategory(name: "Música", value: 2.1, color: .purple),
        StorageCategory(name: "Otros", value: 4.6, color: .green)
    ]
    
    var body: some View {
        ZStack {
           
            VStack(spacing: 30) {

                AppText("Select a category to\npreview content")
                     .font(.BaseRegular)
                     .foregroundColor(.DefaultText)
                     .lineLimit(2)
                     .truncationMode(.tail)
                     .multilineTextAlignment(.center)
                  
                  
                   
                
                ZStack {

                    ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                        let angles = getSegmentAngles(for: index)
                        Circle()
                            .trim(from: angles.start, to: angles.end)
                            .stroke(category.color, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(180))
                    }
            
                    VStack(spacing: 8) {
                        AppText("17.7 GB")
                            .font(.XXLSemibold)
                            .foregroundColor(.DefaultTextStrong)
                        
                        AppText("Save up to 7%\nof your space")
                            .font(.XSRegular)
                            .foregroundColor(.DefaultText)
                            .multilineTextAlignment(.center)
                    }
                    .offset(y: -20)
                }
                .padding(.horizontal, 40)
                
       
            }
        }
    }
    
    private func getSegmentAngles(for index: Int) -> (start: CGFloat, end: CGFloat) {
        let totalValue = categories.reduce(0) { $0 + $1.value }
        let gapPercent: CGFloat = 0.035
        let totalGaps = CGFloat(categories.count - 1) * gapPercent
        let availableSpace: CGFloat = 0.5 - totalGaps
        
        var accumulatedBefore: Double = 0
        for i in 0..<index {
            accumulatedBefore += categories[i].value
        }
        
      
        let currentSegmentValue = categories[index].value
        
      
        let startPercent = CGFloat(accumulatedBefore / totalValue) * availableSpace
        let endPercent = CGFloat((accumulatedBefore + currentSegmentValue) / totalValue) * availableSpace
        
       
        let gapsBefore = CGFloat(index) * gapPercent
        
        return (
            start: startPercent + gapsBefore,
            end: endPercent + gapsBefore
        )
    }
}

struct StorageCategory {
    let name: String
    let value: Double
    let color: Color
}
