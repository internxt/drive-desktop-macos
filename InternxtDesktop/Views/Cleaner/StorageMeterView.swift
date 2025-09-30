//
//  StorageMeterView.swift
//  InternxtDesktop
//
//  Created by Patricio Tovar on 29/8/25.
//
//

import Foundation
import SwiftUI

struct StorageMeterView: View {
    let scanResult: ScanResult?
    let selectedCategoryForPreview: CleanupCategory?
    let selectedCategorySize: UInt64
    let selectedCategories: Set<String>
    let selectedTotalSize: UInt64
    let selectedFilesByCategory: [String: Set<String>]
    
    @State private var systemTotalCapacity: Double = 0.0

    var totalStorage: Double {
        if let selectedCategory = selectedCategoryForPreview {
            return Double(selectedCategory.size) / (1024 * 1024 * 1024)
        }
        else if hasSelections {
            return Double(selectedTotalSize) / (1024 * 1024 * 1024)
        }
        else {
            guard let result = scanResult else { return 0 }
            return Double(result.totalSize) / (1024 * 1024 * 1024)
        }
    }
    
    var totalStorageBytes: UInt64 {
        if let selectedCategory = selectedCategoryForPreview {
            return selectedCategory.size
        }
        else if hasSelections {
            return selectedTotalSize
        }
        else {
            return 0
        }
    }
    
    var formattedStorageSize: String {
        let bytes = totalStorageBytes
        
        if bytes == 0 {
            return "0 KB"
        }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    var hasSelections: Bool {
        return !selectedCategories.isEmpty || selectedFilesByCategory.values.contains { !$0.isEmpty }
    }

    var percentageToSave: Int {
        guard systemTotalCapacity > 0 else { return 0 }
        
        let sizeToDelete: Double
        if let selectedCategory = selectedCategoryForPreview {
            sizeToDelete = Double(selectedCategory.size)
        }
        else if hasSelections {
            sizeToDelete = Double(selectedTotalSize)
        }
        else {
            return 0
        }
        
        let deletableInGB = sizeToDelete / (1024 * 1024 * 1024)
        let totalSystemInGB = systemTotalCapacity / (1024 * 1024 * 1024)
        let percentage = (deletableInGB / totalSystemInGB) * 100
        return Int(percentage.rounded())
    }

    var categories: [StorageCategory] {
        guard let result = scanResult else { return [] }

        let colors: [Color] = [.blue, .orange, .pink, .purple, .green, .red, .cyan, .yellow]

        if let selectedCategory = selectedCategoryForPreview {
            let baseColor = colors[0]
            return [StorageCategory(
                id: selectedCategory.id,
                name: selectedCategory.name,
                value: Double(selectedCategory.size) / (1024 * 1024 * 1024),
                color: baseColor
            )]
        }
        
        return result.categories.enumerated().map { index, category in
            let isSelected = selectedCategories.contains(category.id)
            let baseColor = colors[index % colors.count]
            
            return StorageCategory(
                id: category.id,
                name: category.name,
                value: Double(category.size) / (1024 * 1024 * 1024),
                color: isSelected ? baseColor : Color.gray.opacity(0.4)
            )
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 30) {
                AppText("CLEANER_SELECT_CATEGORY_PREVIEW")
                    .font(.BaseRegular)
                    .foregroundColor(.DefaultText)
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .multilineTextAlignment(.center)

                ZStack {
                    if categories.isEmpty {
                        Circle()
                            .trim(from: 0, to: 0.5)
                            .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                            .frame(width: 200, height: 200)
                            .rotationEffect(.degrees(180))
                    } else {
                        ForEach(Array(categories.enumerated()), id: \.element.id) { index, category in
                            let angles = getSegmentAngles(for: index)
                            Circle()
                                .trim(from: angles.start, to: angles.end)
                                .stroke(category.color, style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                                .frame(width: 200, height: 200)
                                .rotationEffect(.degrees(180))
                        }
                    }

                    VStack(spacing: 8) {
                        AppText(formattedStorageSize)
                            .font(.XXLSemibold)
                            .foregroundColor(.DefaultTextStrong)

                        if scanResult != nil {
                            AppText(String(format: NSLocalizedString("CLEANER_SAVE_SPACE_PERCENTAGE", comment: ""), percentageToSave))
                                .font(.XSRegular)
                                .foregroundColor(.DefaultText)
                                .multilineTextAlignment(.center)
                        } else {
                            AppText("CLEANER_SCANNING")
                                .font(.XSRegular)
                                .foregroundColor(.DefaultText)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .offset(y: -20)
                }
                .padding(.horizontal, 40)
            }
        }
        .onAppear {
            getSystemDiskSpace()
        }
    }

    private func getSegmentAngles(for index: Int) -> (start: CGFloat, end: CGFloat) {
        guard !categories.isEmpty else { return (0, 0) }
        
        let totalValue = categories.reduce(0) { $0 + $1.value }
        guard totalValue > 0 else { return (0, 0) }
        
        let gapSize: CGFloat = 0.003
        let totalGaps = CGFloat(categories.count - 1) * gapSize
        let availableSpace: CGFloat = 0.5 - totalGaps
        
        let minSegmentSize = availableSpace / CGFloat(categories.count) * 0.15
        
        var adjustedValues: [Double] = []
        var totalAdjusted: Double = 0
        
        for category in categories {
            let proportionalSize = CGFloat(category.value / totalValue) * availableSpace
            if proportionalSize < minSegmentSize {
                let adjustedValue = Double(minSegmentSize / availableSpace) * totalValue
                adjustedValues.append(adjustedValue)
                totalAdjusted += adjustedValue
            } else {
                adjustedValues.append(category.value)
                totalAdjusted += category.value
            }
        }
        
        var accumulatedBefore: Double = 0
        for i in 0..<index {
            accumulatedBefore += adjustedValues[i]
        }
        
        let currentSegmentValue = adjustedValues[index]
        
        let startPercent = CGFloat(accumulatedBefore / totalAdjusted) * availableSpace
        let endPercent = CGFloat((accumulatedBefore + currentSegmentValue) / totalAdjusted) * availableSpace
        
        let gapsBeforeSegment = CGFloat(index) * gapSize
        
        return (
            start: startPercent + gapsBeforeSegment,
            end: endPercent + gapsBeforeSegment
        )
    }
    
    func getSystemDiskSpace() {
        let rootURL = URL(fileURLWithPath: "/")
        do {
            let values = try rootURL.resourceValues(forKeys: [.volumeTotalCapacityKey])
            if let total = values.volumeTotalCapacity {
                self.systemTotalCapacity = Double(total)
            }
        } catch {
            print("Error retrieving disk space: \(error)")
        }
    }
}

struct StorageCategory {
    let id: String
    let name: String
    let value: Double
    let color: Color
}
